-- Parse PDF documents from the stage and insert into table
-- Uses Cortex's parse_document function with OCR mode
INSERT INTO PARSED_PRODPDF (FILENAME, EXTRACTED_CONTENT)
SELECT
    t1.RELATIVE_PATH AS FILENAME,
    t1.EXTRACTED_CONTENT
FROM
    (
        SELECT
            RELATIVE_PATH,
            TO_VARCHAR(
                SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
                    '@TPCH_DATA_PRODUCT.ANALYTICS.SAMPLE_STAGE',
                    RELATIVE_PATH,
                    {'mode': 'OCR'}
                ):content
            ) AS EXTRACTED_CONTENT
        FROM
            DIRECTORY('@TPCH_DATA_PRODUCT.ANALYTICS.SAMPLE_STAGE')
    ) AS t1;
