-- ============================================================================
-- External Volume Setup Reference
-- ============================================================================
-- NOTE: This is a REFERENCE file - the user already has external volume set up
-- External volume name: aws_s3_ext_volume_snowflake
-- ============================================================================

-- Example: How to create an external volume (for reference only)

/*
CREATE OR REPLACE EXTERNAL VOLUME aws_s3_ext_volume_snowflake
   STORAGE_LOCATIONS =
      (
         (
            NAME = 'iceberg_s3_location'
            STORAGE_PROVIDER = 'S3'
            STORAGE_BASE_URL = 's3://your-bucket-name/path/'
            STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::123456789012:role/your-role-name'
         )
      )
   COMMENT = 'External volume for Iceberg tables';

-- Get IAM configuration details
DESC EXTERNAL VOLUME aws_s3_ext_volume_snowflake;
*/

-- ============================================================================
-- IAM Policy (attach to AWS role)
-- ============================================================================

/*
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:DeleteObject",
                "s3:DeleteObjectVersion"
            ],
            "Resource": "arn:aws:s3:::your-bucket-name/path/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": "arn:aws:s3:::your-bucket-name",
            "Condition": {
                "StringLike": {
                    "s3:prefix": ["path/*"]
                }
            }
        }
    ]
}
*/

-- ============================================================================
-- IAM Trust Relationship (attach to AWS role after DESC EXTERNAL VOLUME)
-- ============================================================================

/*
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "<SNOWFLAKE_USER_ARN_FROM_DESC>"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "sts:ExternalId": "<EXTERNAL_ID_FROM_DESC>"
                }
            }
        }
    ]
}
*/

-- ============================================================================
-- Verify External Volume
-- ============================================================================

-- Check external volume exists and is configured
DESC EXTERNAL VOLUME aws_s3_ext_volume_snowflake;

-- Show all external volumes
SHOW EXTERNAL VOLUMES;
