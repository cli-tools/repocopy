repocopy 
========

Copy a source repository to a target repository.
Useful for Kubernetes deployments where containers
are marked and tested in a staging environment
before being released to production.

Design
------

1. Obtain the credentials required to pull from
   the source repository and push to the target
   repository.
2. Fetch the manifest blob from the source.
3. Copy the image layers from the source
   to the target repository.
4. PUT the manifest to the target.

Concepts
--------

- username and password for obtaining bearer token
- bearer token for the repository actions
- image manifest
- image layers
