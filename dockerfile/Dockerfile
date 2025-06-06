FROM registry.access.redhat.com/ubi9:latest

# Install dependencies
RUN dnf install -y unzip tar gzip openssh openssh-clients rsync less \
    && dnf clean all

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && rm -rf awscliv2.zip \
    && ./aws/install

# Install OpenShift CLI (oc)
ARG OC_VERSION=latest
RUN curl -L "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OC_VERSION}/openshift-client-linux.tar.gz" -o "openshift-client-linux.tar.gz" \
    && tar -xvzf openshift-client-linux.tar.gz -C /usr/local/bin/ \
    && chmod +x /usr/local/bin/oc \
    && rm -f openshift-client-linux.tar.gz

# Verify installations
RUN aws --version && oc version

# Add a user
RUN useradd -m -u 1000 -d /home/kni -s /bin/bash kni

# Set the user to run the container
USER 1000

# Specify the working directory for the new user
WORKDIR /home/kni
