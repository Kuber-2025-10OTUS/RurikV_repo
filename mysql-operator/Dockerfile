FROM python:3.10-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir kopf kubernetes

# Copy operator code
COPY mysql_operator.py .

# Run the operator
CMD ["python", "mysql_operator.py"]