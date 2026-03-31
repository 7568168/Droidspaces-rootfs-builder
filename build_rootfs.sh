#!/bin/bash
# Configuration
: "${VERSION:=dev}"
DATE=$(date +%Y%m%d)

echo "Starting Droidspaces RootFS Multi-Build System..."

# Install QEMU handlers for cross-platform builds
docker run --privileged --rm tonistiigi/binfmt --install all

echo "Environment diagnostics:"
ls -la
pwd

# Ensure builder exists and is selected
if ! docker buildx inspect droidspaces-builder >/dev/null 2>&1; then
    echo "Creating new buildx builder: droidspaces-builder"
    docker buildx create --name droidspaces-builder --driver docker-container --use
else
    echo "Using existing buildx builder: droidspaces-builder"
    docker buildx use droidspaces-builder
fi

# Bootstrap the builder to ensure it's ready
docker buildx inspect --bootstrap || echo "Warning: Bootstrap failed, attempting to continue..."

# Loop through all available Dockerfile.builder files
shopt -s nullglob
BUILD_COUNT=0
for DOCKERFILE in *.Dockerfile.builder; do
    [ -e "$DOCKERFILE" ] || continue
    ((BUILD_COUNT++))
    
    # Extract prefix (e.g., Ubuntu-24.04 from Ubuntu-24.04.Dockerfile.builder)
    PREFIX=$(echo "$DOCKERFILE" | sed 's/\.Dockerfile\.builder//')
    
    echo "========================================================="
    echo " Building RootFS: $PREFIX"
    echo " Using Dockerfile: $DOCKERFILE"
    echo "========================================================="
    
    # Names for this iteration
    TEMP_TAR="custom-${PREFIX}-rootfs.tar"
    FINAL_NAME="${PREFIX}-Droidspaces-rootfs-${DATE}-${VERSION}.tar.gz"
    
    # Build the rootfs using buildx
    docker buildx build \
      --platform linux/arm64 \
      --target export \
      --output type=tar,dest="$TEMP_TAR" \
      -f "$DOCKERFILE" \
      .

    # Compress with maximum compression
    echo "Compressing $TEMP_TAR..."
    gzip -9 -f "$TEMP_TAR"

    # Keep in current directory (repo root)
    echo "Finalizing: $FINAL_NAME"
    mv "${TEMP_TAR}.gz" "$FINAL_NAME"
    
    echo "Successfully completed: $FINAL_NAME"
done

if [ "$BUILD_COUNT" -eq 0 ]; then
    echo "No *.Dockerfile.builder files found in $(pwd)"
    exit 1
fi

echo "========================================================="
echo " All builds completed successfully! ($BUILD_COUNT rootfs total)"
echo "========================================================="
