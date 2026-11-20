# run.sh
# Run image builder
# Ensure kube_version property is set in resulting image
# Create a new cluster template

set -e
set -o pipefail

# log function
RUN_LOG_DIR="/image-builder-log"
log () {
  tee --ignore-interrupts -a $RUN_LOG_DIR/run.log
}

# print date
info () {
  echo "[ INFO ] $(date "+%Y-%m-%d %H:%M") -- $@"
}

# print date
error () {
  echo "[ ERROR ] $(date "+%Y-%m-%d %H:%M") -- $@"
}

# Ensure host and container UIDs match; otherwise, you'd run into permissions issues from ssh, git, mkdir, etc.
if [[ "$(id -u)" -ne "$BUILD_UID" ]]
then
  error "Host UID ($(id -u)) does not match container's BUILD_UID ($(echo $BUILD_UID))"
  error "Please rebuild docker image using the following flag: --build-arg BUILD_UID=$(id -u)"
  exit 1
fi

source /home/ubuntu/openrc.sh

############### Run image builder ###############

info "Running image builder" | log

# Get UUIDs for the SOURCE_IMAGE and NETWORK
info "Ensuring SOURCE_IMAGE, NETWORK, SOURCE_IMAGE_FLAVOR, and SSH_KEYPAIR_NAME are valid" | log
SOURCE_IMAGE_UUID=$(openstack image show $SOURCE_IMAGE -f value -c id)
NETWORK_UUID=$(openstack network show $NETWORK -f value -c id)
SOURCE_IMAGE_FLAVOR=$(openstack flavor list -f value -c name | grep -e "^$SOURCE_IMAGE_FLAVOR\$")
SSH_KEYPAIR_NAME=$(openstack keypair show $SSH_KEYPAIR_NAME -f value -c name)
info "SOURCE_IMAGE_UUID=$SOURCE_IMAGE_UUID" | log
info "NETWORK_UUID=$NETWORK_UUID" | log
info "SOURCE_IMAGE_FLAVOR=$SOURCE_IMAGE_FLAVOR" | log
info "SSH_KEYPAIR_NAME=$SSH_KEYPAIR_NAME" | log

ROLES_DIR="/custom-roles"
info "Searching for custom ansible roles in $ROLES_DIR" | log

list_dirs() {
  find $1 -type d \
    -maxdepth 1 \
    -not -wholename $1 \
    -exec realpath {} \; \
    2>/dev/null
}


FIRST_BOOT_CUSTOM_ROLES_PRE=($(list_dirs $ROLES_DIR/first_boot_pre))
FIRST_BOOT_CUSTOM_ROLES_POST=($(list_dirs $ROLES_DIR/first_boot_post))
NODE_CUSTOM_ROLES_PRE=($(list_dirs $ROLES_DIR/pre))
NODE_CUSTOM_ROLES_POST=($(list_dirs $ROLES_DIR/post))
NODE_CUSTOM_ROLES_POST_SYSPREP=($(list_dirs $ROLES_DIR/post_sysprep))

info "Found custom roles:" | log
info "FIRST_BOOT_CUSTOM_ROLES_PRE: ${FIRST_BOOT_CUSTOM_ROLES_PRE[@]}" | log
info "FIRST_BOOT_CUSTOM_ROLES_POST: ${FIRST_BOOT_CUSTOM_ROLES_POST[@]}" | log
info "NODE_CUSTOM_ROLES_PRE: ${NODE_CUSTOM_ROLES_PRE[@]}" | log
info "NODE_CUSTOM_ROLES_POST: ${NODE_CUSTOM_ROLES_POST[@]}" | log
info "NODE_CUSTOM_ROLES_POST_SYSPREP: ${NODE_CUSTOM_ROLES_POST_SYSPREP[@]}" | log

# Construct a packer var_file.json
info "Creating $RUN_LOG_DIR/var_file.json" | log
VAR_FILE=$(cat <<VAR_FILE
{
  "source_image": "$SOURCE_IMAGE_UUID",
  "networks": "$NETWORK_UUID",
  "flavor": "$SOURCE_IMAGE_FLAVOR",
  "floating_ip_network": "",
  "use_floating_ip": "false",
  "image_name": "$IMAGE_NAME",
  "image_visibility": "private",
  "image_disk_format": "",
  "use_blockstorage_volume": "false",
  "volume_size": "",
  "volume_type": "",
  "security_groups": "image-builder",
  "ssh_username": "$SSH_USERNAME",
  "ssh_keypair_name": "$SSH_KEYPAIR_NAME",
  "ssh_private_key_file": "~/.ssh/id_ed25519_packer",
  "first_boot_custom_roles_pre": "${FIRST_BOOT_CUSTOM_ROLES_PRE[@]}",
  "first_boot_custom_roles_post": "${FIRST_BOOT_CUSTOM_ROLES_POST[@]}",
  "node_custom_roles_pre": "${NODE_CUSTOM_ROLES_PRE[@]}",
  "node_custom_roles_post": "${NODE_CUSTOM_ROLES_POST[@]}",
  "node_custom_roles_post_sysprep": "${NODE_CUSTOM_ROLES_POST_SYSPREP[@]}"
}
VAR_FILE
)
echo $VAR_FILE > $RUN_LOG_DIR/var_file.json

# Build the image
info "Building new CAPI image"
info "See $RUN_LOG_DIR/run.log"
make build-openstack-ubuntu-2204 | log
