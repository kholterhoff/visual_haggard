# AWS S3 Setup Guide for Visual Haggard

This guide explains how to configure AWS S3 for image storage in production while keeping local storage for development.

## Overview

- **Development (localhost)**: Images stored locally in `storage/` directory
- **Production (visualhaggard.org)**: Images stored in AWS S3 bucket

## Prerequisites

1. AWS Account
2. AWS IAM user with S3 permissions
3. S3 bucket created

## Step 1: Create AWS S3 Bucket

1. Log in to [AWS Console](https://console.aws.amazon.com/)
2. Navigate to S3 service
3. Click "Create bucket"
4. Configure bucket:
   - **Bucket name**: `visual-haggard-production` (or your preferred name)
   - **Region**: Choose closest to your users (e.g., `us-east-1`)
   - **Block Public Access**: Uncheck "Block all public access" (we need public read access for images)
   - **Bucket Versioning**: Enable (recommended for backup)
5. Click "Create bucket"

## Step 2: Configure Bucket Policy

Add this policy to allow public read access to images:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::visual-haggard-production/*"
        }
    ]
}
```

To add this policy:
1. Go to your bucket
2. Click "Permissions" tab
3. Scroll to "Bucket policy"
4. Click "Edit" and paste the policy above
5. Replace `visual-haggard-production` with your bucket name
6. Click "Save changes"

## Step 3: Create IAM User

1. Navigate to IAM service in AWS Console
2. Click "Users" → "Add users"
3. User name: `visual-haggard-app`
4. Select "Access key - Programmatic access"
5. Click "Next: Permissions"
6. Click "Attach existing policies directly"
7. Search and select: `AmazonS3FullAccess`
8. Click through to create user
9. **IMPORTANT**: Save the Access Key ID and Secret Access Key (you won't see them again!)

## Step 4: Configure Production Environment Variables

When deploying to production, set these environment variables:

```bash
AWS_ACCESS_KEY_ID=your_access_key_id
AWS_SECRET_ACCESS_KEY=your_secret_access_key
AWS_REGION=us-east-1
S3_BUCKET=visual-haggard-production
```

### For Heroku:
```bash
heroku config:set AWS_ACCESS_KEY_ID=your_access_key_id
heroku config:set AWS_SECRET_ACCESS_KEY=your_secret_access_key
heroku config:set AWS_REGION=us-east-1
heroku config:set S3_BUCKET=visual-haggard-production
```

### For Other Platforms:
- **AWS Elastic Beanstalk**: Add to environment properties
- **Docker/Kubernetes**: Add to environment variables in deployment config
- **VPS/Server**: Add to `.env` file or system environment

## Step 5: Install Dependencies

Run this command to install the AWS SDK gem:

```bash
bundle install
```

## Step 6: Test Configuration

### In Development (Local):
Images will automatically be stored in `storage/` directory. No AWS credentials needed.

```bash
rails console
# Upload a test image through the admin panel
# Check that it's stored in storage/ directory
```

### In Production:
After deploying with environment variables set:

```bash
# SSH into production server or use Heroku console
rails console
# Upload a test image through the admin panel
# Verify it appears in your S3 bucket
```

## Configuration Files

The following files have been configured:

### `config/storage.yml`
```yaml
amazon:
  service: S3
  access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region: <%= ENV['AWS_REGION'] || 'us-east-1' %>
  bucket: <%= ENV['S3_BUCKET'] || 'visual-haggard-production' %>
```

### `config/environments/development.rb`
```ruby
config.active_storage.service = :local
```

### `config/environments/production.rb`
```ruby
config.active_storage.service = :amazon
```

## Image URLs

### Development:
Images will be served from: `http://localhost:3000/rails/active_storage/blobs/...`

### Production:
Images will be served from: `https://visual-haggard-production.s3.amazonaws.com/...`

Or if you configure CloudFront CDN: `https://your-cloudfront-domain.cloudfront.net/...`

## Optional: CloudFront CDN Setup

For better performance, you can add CloudFront CDN in front of your S3 bucket:

1. Go to CloudFront in AWS Console
2. Create a new distribution
3. Set origin to your S3 bucket
4. Configure caching settings
5. Update your Rails config to use CloudFront URL

## Migrating Existing Images to S3

If you have existing images in local storage that need to be moved to S3:

```bash
# This will be implemented in a rake task
rails s3:migrate_images
```

## Troubleshooting

### Images not loading in production:
1. Check environment variables are set correctly
2. Verify S3 bucket policy allows public read
3. Check AWS credentials have S3 permissions
4. Look at Rails logs for specific errors

### Permission denied errors:
- Verify IAM user has `AmazonS3FullAccess` policy
- Check bucket policy allows the actions needed

### CORS errors:
Add CORS configuration to your S3 bucket:
```json
[
    {
        "AllowedHeaders": ["*"],
        "AllowedMethods": ["GET", "HEAD"],
        "AllowedOrigins": ["https://visualhaggard.org"],
        "ExposeHeaders": []
    }
]
```

## Security Best Practices

1. **Never commit AWS credentials** to version control
2. Use environment variables for all sensitive data
3. Rotate access keys periodically
4. Use IAM roles instead of access keys when possible (e.g., on EC2)
5. Enable S3 bucket versioning for backup
6. Consider enabling S3 bucket encryption
7. Set up CloudWatch alarms for unusual S3 activity

## Cost Estimation

AWS S3 pricing (as of 2024):
- Storage: ~$0.023 per GB/month
- GET requests: $0.0004 per 1,000 requests
- Data transfer out: First 1 GB free, then ~$0.09 per GB

For a typical archive with 10,000 images (~50GB):
- Storage: ~$1.15/month
- Requests: Minimal (< $1/month)
- Transfer: Depends on traffic

## Support

For issues or questions:
- AWS Documentation: https://docs.aws.amazon.com/s3/
- Rails Active Storage Guide: https://guides.rubyonrails.org/active_storage_overview.html