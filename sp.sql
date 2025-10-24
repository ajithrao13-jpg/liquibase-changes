--liquibase formatted sql

--changeset siva:sp_test_message
CREATE OR REPLACE PROCEDURE sp_test_message()
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE NOTICE 'Hello from Liquibase test stored procedure!';
END;
$$;
--rollback DROP PROCEDURE IF EXISTS sp_test_message;
