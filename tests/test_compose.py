import json
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parent.parent
PREFLIGHT = runpy.run_path(str(ROOT / "bin/preflight"))


class ComposeMigrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.models = {}
        for environment in ("prod", "preprod"):
            env = dict(os.environ, ENV=environment, N100_LAN_IP="192.0.2.10", DNS_SECONDARY_IP="192.0.2.11")
            result = subprocess.run(
                [str(ROOT / "bin/compose"), "config", "--format", "json"],
                env=env, check=True, capture_output=True, text=True,
            )
            cls.models[environment] = json.loads(result.stdout)

    def test_service_inventory_and_enablement(self):
        expected = {
            "beszel", "beszel-agent", "pihole", "traefik", "home-assistant",
            "mosquitto", "zigbee2mqtt", "audiobookshelf", "kavita", "pocket-id",
            "trek", "immich-redis", "immich-postgres", "immich-machine-learning",
            "immich-server", "jellyfin",
        }
        for environment, model in self.models.items():
            self.assertEqual(set(model["services"]), expected)
            disabled = {name for name, service in model["services"].items() if service["scale"] == 0}
            if environment == "prod":
                self.assertEqual(disabled, {"beszel-agent"})
            else:
                self.assertEqual(disabled, {
                    "beszel", "beszel-agent", "pihole", "traefik", "mosquitto",
                    "zigbee2mqtt", "immich-redis", "immich-postgres",
                    "immich-machine-learning", "immich-server",
                })

    def test_saved_application_hostnames_remain_resolvable(self):
        for environment, model in self.models.items():
            for name in ("mosquitto", "immich-postgres", "immich-redis", "immich-machine-learning"):
                aliases = model["services"][name]["networks"]["backend"]["aliases"]
                self.assertIn(f"homelab-{environment}_{name}", aliases)

    def test_backend_networks_are_separate_and_not_shared_with_ingress(self):
        self.assertNotEqual(self.models["prod"]["networks"]["backend"]["name"],
                            self.models["preprod"]["networks"]["backend"]["name"])
        for model in self.models.values():
            self.assertEqual(model["networks"]["ingress"]["name"], "homelab-ingress")
            for name in ("mosquitto", "immich-postgres", "immich-redis", "immich-machine-learning"):
                self.assertNotIn("ingress", model["services"][name]["networks"])

    def test_routing_uses_container_labels_and_the_shared_bridge(self):
        for environment, model in self.models.items():
            command = model["services"]["traefik"]["command"]
            self.assertIn("--providers.docker=true", command)
            self.assertFalse(any("providers.swarm" in arg for arg in command))
            for service in model["services"].values():
                labels = service["labels"]
                if labels.get("traefik.enable") == "true":
                    self.assertEqual(labels["traefik.docker.network"], "homelab-ingress")
                    self.assertIn("ingress", service["networks"])
            labels = model["services"]["jellyfin"]["labels"]
            self.assertEqual(labels[f"traefik.http.services.jellyfin-{environment}.loadbalancer.server.port"], "8096")

    def test_beszel_uses_local_socket_and_host_metrics_without_a_tcp_listener(self):
        for environment, model in self.models.items():
            hub = model["services"]["beszel"]
            agent = model["services"]["beszel-agent"]
            self.assertEqual(hub["image"], agent["image"].replace("beszel-agent:", "beszel:"))
            self.assertEqual(agent["network_mode"], "host")
            self.assertNotIn("ports", agent)
            self.assertNotIn("networks", agent)
            self.assertEqual(agent["environment"]["LISTEN"], "/beszel_socket/beszel.sock")
            hub_mounts = {v["target"]: v for v in hub["volumes"]}
            agent_mounts = {v["target"]: v for v in agent["volumes"]}
            self.assertEqual(hub_mounts["/beszel_socket"]["source"], agent_mounts["/beszel_socket"]["source"])
            self.assertEqual(hub_mounts["/beszel_data"]["source"], f"/srv/data/{environment}/beszel/data")
            for target in ("/var/run/docker.sock", "/extra-filesystems/root", "/extra-filesystems/data"):
                self.assertTrue(agent_mounts[target]["read_only"])
            self.assertEqual(agent["environment"]["FILESYSTEM"], "/extra-filesystems/root")
            for service in (hub, agent):
                self.assertTrue(all(not v.get("bind", {}).get("create_host_path", False) for v in service["volumes"]))
            self.assertFalse(any(name.startswith("homepage") for name in model["services"]))
            self.assertFalse(any(label.startswith("homepage.") for service in model["services"].values()
                                 for label in service["labels"]))

    def test_dns_uses_two_host_addresses_and_no_pi_wildcard(self):
        for model in self.models.values():
            ports = model["services"]["pihole"]["ports"]
            self.assertEqual({(p["host_ip"], p["protocol"]) for p in ports}, {
                ("192.0.2.10", "tcp"), ("192.0.2.10", "udp"),
                ("192.0.2.11", "tcp"), ("192.0.2.11", "udp"),
            })
            content = model["configs"]["pihole_custom_dns"]["content"]
            self.assertIn("address=/lan.barlows.cool/192.0.2.10", content)
            self.assertNotIn("192.168.1.204", content)
            self.assertEqual(model["services"]["pihole"]["environment"]["WEBPASSWORD_FILE"], "pihole_web_password")

    def test_hardware_and_existing_data_paths_are_preserved(self):
        for environment, model in self.models.items():
            services = model["services"]
            zigbee = services["zigbee2mqtt"]
            self.assertEqual(zigbee["devices"][0]["target"], "/dev/ttyUSB0")
            self.assertEqual(zigbee["environment"]["ZIGBEE2MQTT_CONFIG_SERIAL_PORT"], "/dev/ttyUSB0")
            self.assertEqual(services["jellyfin"]["devices"][0]["source"], "/dev/dri")
            for name, target, source in (
                ("pocket-id", "/app/data", f"/srv/data/{environment}/pocket-id/data"),
                ("immich-postgres", "/var/lib/postgresql/data", f"/srv/data/{environment}/immich/postgres"),
                ("immich-server", "/data", f"/srv/data/{environment}/immich/upload"),
                ("jellyfin", "/config", f"/srv/data/{environment}/jellyfin/config"),
                ("traefik", "/letsencrypt", f"/srv/data/{environment}/traefik/letsencrypt"),
            ):
                mount = next(v for v in services[name]["volumes"] if v["target"] == target)
                self.assertEqual(mount["source"], source)
                self.assertFalse(mount.get("bind", {}).get("create_host_path", False))
            for secret in model["secrets"].values():
                self.assertIn(f"/{environment}/", secret["file"])
                self.assertNotIn("external", secret)


class PreflightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.root.chmod(0o700)
        self.secret = self.root / "encryption_key"
        self.secret.write_text("fixture-secret")
        self.secret.chmod(0o444)
        self.data = self.root / "data"
        self.data.mkdir()
        self.model = {
            "services": {"pocket-id": {
                "scale": 1, "volumes": [{"type": "bind", "source": str(self.data)}],
                "secrets": [{"source": "key"}],
            }},
            "secrets": {"key": {"file": str(self.secret)}}, "configs": {},
        }

    def test_existing_protected_secrets_and_storage_pass(self):
        self.assertEqual(PREFLIGHT["validate"](self.model), [])

    def test_missing_data_and_secrets_are_reported_without_values(self):
        self.data.rmdir()
        self.secret.unlink()
        errors = "\n".join(PREFLIGHT["validate"](self.model))
        self.assertIn("missing bind source", errors)
        self.assertIn("missing or empty secret", errors)
        self.assertNotIn("fixture-secret", errors)

    def test_secret_directory_must_protect_container_readable_files(self):
        self.root.chmod(0o755)
        self.assertTrue(any("0700" in e for e in PREFLIGHT["validate"](self.model)))

    def test_disabled_services_do_not_require_unrecovered_secrets(self):
        self.model["services"]["pocket-id"]["scale"] = 0
        self.secret.unlink()
        self.assertEqual(PREFLIGHT["validate"](self.model), [])

    def test_enabled_beszel_agent_requires_pairing_but_disabled_agent_does_not(self):
        agent = {"scale": 0, "environment": {"KEY": ""}}
        model = {"services": {"beszel-agent": agent}}
        self.assertEqual(PREFLIGHT["validate"](model), [])
        agent["scale"] = 1
        self.assertTrue(any("hub public key" in e for e in PREFLIGHT["validate"](model)))
        agent["environment"]["KEY"] = "ssh-ed25519 public-key-fixture"
        self.assertEqual(PREFLIGHT["validate"](model), [])

    def test_unknown_service_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Unknown services"):
            PREFLIGHT["enabled_services"](self.model, ["typo"])

    def test_dependencies_are_checked_for_targeted_start(self):
        self.model["services"]["app"] = {"scale": 1, "depends_on": {"pocket-id": {}}}
        self.secret.unlink()
        self.assertTrue(PREFLIGHT["validate"](self.model, ["app"]))

    def test_swarm_membership_prevents_startup_even_without_local_tasks(self):
        main = PREFLIGHT["main"]
        with patch.dict(main.__globals__, __file__=str(ROOT / "bin/preflight")):
            with patch("subprocess.check_output", side_effect=[json.dumps(self.model), "active\n"]):
                with patch.object(os, "environ", dict(os.environ, ENV="prod")):
                    with patch.object(__import__("sys"), "argv", ["preflight"]):
                        with self.assertRaisesRegex(ValueError, "still in Swarm"):
                            main()

    def test_old_containers_prevent_parallel_writers_after_leaving_swarm(self):
        with patch("subprocess.check_output", side_effect=[json.dumps(self.model), "inactive\n", "old-task\n"]):
            with patch.object(os, "environ", dict(os.environ, ENV="prod")):
                with patch.object(__import__("sys"), "argv", ["preflight"]):
                    with self.assertRaisesRegex(ValueError, "Old prod containers still run"):
                        PREFLIGHT["main"]()

    def test_dns_addresses_must_be_distinct_and_assigned_to_host(self):
        self.model["services"] = {"pihole": {
            "scale": 1, "ports": [{"host_ip": "192.0.2.10"}],
        }}
        errors = PREFLIGHT["validate"](self.model)
        self.assertTrue(any("distinct" in error for error in errors))
        self.assertTrue(any("not assigned" in error for error in errors))

    def test_missing_hardware_is_reported_before_start(self):
        self.model["services"]["pocket-id"]["devices"] = [{"source": str(self.root / "missing-device")}]
        self.assertTrue(any("missing device" in error for error in PREFLIGHT["validate"](self.model)))

    def test_legacy_jellyfin_routes_are_rejected(self):
        dynamic = self.root / "dynamic"
        dynamic.mkdir()
        (dynamic / "jellyfin-prod.yml").write_text("legacy-route")
        self.model["services"]["traefik"] = {"scale": 1, "volumes": [{
            "type": "bind", "source": str(dynamic), "target": "/etc/traefik/dynamic",
        }]}
        self.assertTrue(any("legacy Jellyfin" in error for error in PREFLIGHT["validate"](self.model)))


if __name__ == "__main__":
    unittest.main()
