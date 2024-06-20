## Example HTTP API wrapper for pdf2htmlEX

This is an example of a simple HTTP API wrapper for pdf2htmlEX. It is written in Pyhton using the FastAPI framework.


### Building
It can be built by building the docker image with the target of `api`

```bash
# In the top level of the git repo
docker build -t pdf2html-ex-api --target api .
```

### Runtime options


```bash
# The port to run the server on
PDF2HTML_PORT=8000

# Number of gunicorn workers to run, if 1, uvicorn will be used with one worker
NUM_WORKERS=1

# Sentry error reporting config
SENTRY_ENABLED=0
SENTRY_DSN=""
SENTRY_ENVIRONMENT="pdf2html"
SENTRY_RELEASE=""

```


### Development
With a pyhton virtualenv of python >=3.10, run `poetry install`

Typechecking can be run with `mypy`

Linting can be run with `ruff check .`

Formatting can be run with `ruff format .`