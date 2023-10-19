FORmicidae Tracker (FORT) : Ansible IT Automation Scripts

The [FORmicidae Tracker (FORT)](https://formicidae-tracker.github.io) is an advanced online tracking system designed specifically for studying social insects, particularly ants and bees, FORT utilizes fiducial markers for extended individual tracking. Its key features include real-time online tracking and a modular design architecture that supports distributed processing. The project's current repositories encompass comprehensive hardware blueprints, technical documentation, and associated firmware and software for online tracking and offline data analysis.

This repository contains the Ansible (IT automation) scripts to deploy and administrate the FORT system.

## Mandatory variable

For a proper configuration, one must set some sensible variables in
`group_vars/vault`. Make sure to encrypt them properly if you push
them in a SMC.

## Site branches

The two main production site of FORT maitains their configuration with
encrypted variable in their own branches.

By default they are configured to use a password stored in the file
`vault_password`, for the `inventory` and `group_vars/vault` file.

## License

Theses scripts are released under the GNU GPL version 3 or later. See the LICENSE file.
