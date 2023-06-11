CREATE TABLE IF NOT EXISTS
  finance.years (id serial NOT NULL, year integer NULL);

DO
$$
BEGIN
    IF NOT EXISTS (
	SELECT 1
	FROM pg_constraint
	WHERE conname = 'years_pkey'
	) THEN
	  ALTER TABLE
  	  finance.years
	  ADD CONSTRAINT years_pkey PRIMARY KEY (id);
	END IF;
END
$$;

CREATE TABLE IF NOT EXISTS
  finance.month (
    id serial NOT NULL,
    cardinal integer NULL,
    name text NOT NULL
  );

DO
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_constraint
        WHERE  conname = 'month_pkey'
    ) THEN
        ALTER TABLE finance.month
        ADD CONSTRAINT month_pkey PRIMARY KEY (id);
    END IF;
END
$$;
