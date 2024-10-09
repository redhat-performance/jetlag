This directory is a holding area for materials which will be used to create a
Jetlag continuous integration (CI) system, to automate building and testing of
Jetlag for development and quality assurance.

Currently, there is only one file, deploy_sno.sh, which is an initial effort
at scripting the deployment of a single-node OpenShift cluster using Jetlag.
It is targetted at a Scale Lab deployment, but the techniques it uses should
be applicable across all deployments.  It is currently highly opinionated, but
it should be straightforward to generalize it into a form which could be used
as a runner by Jenkins.
