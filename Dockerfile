FROM ruby:3.2

# Install OS packages needed for net-ssh gems
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    ssh \
    libffi-dev \
    libgmp-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Puppet Bolt
RUN gem install bolt ed25519 bcrypt_pbkdf

# Create non-root user (optional, but good practice)
RUN useradd -m boltuser
USER boltuser
WORKDIR /home/boltuser/workspace

ENTRYPOINT ["bolt"]
