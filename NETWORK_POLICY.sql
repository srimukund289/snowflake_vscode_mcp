------Create Network Policy and assign you public ip address-----------
CREATE OR REPLACE NETWORK POLICY snow_mcp_policy ALLOWED_IP_LIST = ('<your_public_ip_address>/32');
ALTER ACCOUNT SET NETWORK_POLICY = snow_mcp_policy;
