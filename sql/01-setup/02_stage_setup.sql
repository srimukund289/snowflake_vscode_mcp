-- Create an internal stage for uploading files (PDFs, etc.)
CREATE OR REPLACE STAGE SAMPLE_STAGE
	DIRECTORY = ( ENABLE = true ) 
	ENCRYPTION = ( TYPE = 'SNOWFLAKE_SSE' );
