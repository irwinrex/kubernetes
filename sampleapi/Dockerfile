###############
# BUILD IMAGES #
###############
FROM python:3.11 as builder

RUN set -ex \
    # Upgrade the package index and install security upgrades
    && apt-get update \
    && apt-get upgrade -y \
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip to a specific version
RUN pip install --upgrade pip

# Copy the requirements file into the container
COPY requirements.txt .

# Install the requirements
RUN pip install --no-cache-dir -r requirements.txt

# Clean up
RUN set -ex \
    apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

###############
# FINAL IMAGE #
###############
FROM python:3.11-slim

# Set the working directory
WORKDIR /app

# Copy the rest of the application code into the container
COPY ./ /app

# Copy Python libraries from the BASE Image
COPY --from=builder /usr/local/lib/python3.11/ /usr/local/lib/python3.11/
COPY --from=builder /usr/local/bin/uwsgi  /usr/local/bin/uwsgi

# Creating User
RUN addgroup --system python && adduser --system --group python

# Install additional Python packages and uWSGI-related packages
RUN set -ex \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        libxml2-dev \
        libssl-dev \
        curl \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*
    
# Change ownership of the app directory to the python user
RUN chown -R python:python /app

# Switch to the python user
USER python

# Expose port 7000 for the Django app
EXPOSE 7000

# Start the application
CMD ["uwsgi", "--ini", "/app/uwsgi.ini"]
# CMD ["python", "manage.py", "runserver", "0.0.0.0:7000"]