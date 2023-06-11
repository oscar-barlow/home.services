DO
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_constraint
        WHERE  conname = 'month_cardinal_check'
    ) THEN
        ALTER TABLE finance.month
        ADD CONSTRAINT month_cardinal_check CHECK (cardinal >= 1 AND cardinal <= 12);
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM   pg_constraint
        WHERE  conname = 'month_name_length_check'
    ) THEN
        ALTER TABLE finance.month
        ADD CONSTRAINT month_name_length_check CHECK (length(name) <= 9);
    END IF;
END
$$;

