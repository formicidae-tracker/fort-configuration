# Ansible configuration for the FORmicidae Tracker

This repository holds the ansible roles and configuration of the fort system.

## Mandatory variable

For a proper configuration, one must set some sensible variables in
`group_vars/vault`. Make sure to encrypt them properly if you push
them in a SMC.

## Site branches

The two main production site of FORT maitains their configuration with
encrypted variable in their own branches.

By default they are configured to use a password stored in the file
`vault_password`, for the `inventory` and `group_vars/vault` file.
