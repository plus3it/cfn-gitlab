### "Parent" Templates.

The templates with "parent" in their names are, at their heart, "driver" templates. The GitLab service's deployment is broken up into discrete functional areas. This allows for easier code re-use as well as service-deployment into environments where a given AWS user/role doesn't have sufficient privileges to do _all_ of the relevant AWS-level tasks. In environments where users/roles _do_ have such privileges, individually running each template can be repetitive and onerous. The "parent" templates coordinate the running of all the sub-tasks, automatically sharing common configuration data between child stacks as appropriate.

The "parent" stacks are named in a manner to indicate what they do. All environmental permissions-restriction cases cannot be identified, so only "top-to-bottom" parent stacks are included. If your environment requires creation of other "parent" stacks, please feel free to [contribute](/.github/contributing.md) them back to this project
