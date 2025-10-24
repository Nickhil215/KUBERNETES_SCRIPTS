#!/bin/bash
# ----------------------------------------------------
# MinIO ILM Setup and Cluster Resource Info Script
# ----------------------------------------------------

# Configuration
ALIAS_NAME="myminio"
MINIO_URL="http://localhost:9000"
ACCESS_KEY="minio"
SECRET_KEY="K7712XV0U4HRXJOCL8JJFPBVUNFNZL"
BUCKET_NAME="mlpipeline"
EXPIRE_DAYS=1

echo "🔧 Setting up MinIO client alias..."
mc alias set "$ALIAS_NAME" "$MINIO_URL" "$ACCESS_KEY" "$SECRET_KEY"
if [ $? -ne 0 ]; then
  echo "❌ Failed to set alias. Exiting..."
  exit 1
fi

echo ""
echo "📊 Checking MinIO server info..."
mc admin info "$ALIAS_NAME"
if [ $? -ne 0 ]; then
  echo "❌ Could not fetch MinIO info. Check if the server is running."
  exit 1
fi

echo ""
echo "🗂️ Listing existing buckets..."
mc ls "$ALIAS_NAME"

echo ""
echo "⚙️ Adding lifecycle rule to bucket: $BUCKET_NAME (Expire after $EXPIRE_DAYS days)..."
mc ilm rule add "$ALIAS_NAME/$BUCKET_NAME" --expire-days "$EXPIRE_DAYS"
if [ $? -ne 0 ]; then
  echo "❌ Failed to add lifecycle rule. Ensure bucket '$BUCKET_NAME' exists."
  exit 1
fi

echo ""
echo "📋 Listing ILM rules for bucket: $BUCKET_NAME"
mc ilm rule ls "$ALIAS_NAME/$BUCKET_NAME"

echo ""
echo "📦 Kubernetes Node Resource Usage:"
kubectl top nodes || echo "⚠️ Could not fetch node metrics. Ensure metrics-server is installed."

echo ""
echo "✅ Script execution completed successfully."
