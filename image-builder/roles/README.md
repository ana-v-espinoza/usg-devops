# Custom Roles

Place custom `ansible` roles in the appropriate directory as described in the [image-builder docs](https://image-builder.sigs.k8s.io/capi/capi#customization). The roles found in the directories below refer to the following variables in the docs:

- `./first_boot_pre`: `firstboot_custom_roles_pre`
- `./first_boot_post`: `firstboot_custom_roles_post`
- `./pre`: `node_custom_roles_pre`
- `./post`: `node_custom_roles_post`
- `./post_sysprep`: `node_custom_roles_post_sysprep`
