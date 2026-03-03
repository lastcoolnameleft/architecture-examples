from flask import Flask, request, render_template
import os
import random
import redis
import socket
import sys
import logging

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s [%(levelname)s] %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Load configurations from environment or config file
app.config.from_pyfile('config_file.cfg')

if ("VOTE1VALUE" in os.environ and os.environ['VOTE1VALUE']):
    button1 = os.environ['VOTE1VALUE']
else:
    button1 = app.config['VOTE1VALUE']

if ("VOTE2VALUE" in os.environ and os.environ['VOTE2VALUE']):
    button2 = os.environ['VOTE2VALUE']
else:
    button2 = app.config['VOTE2VALUE']

if ("TITLE" in os.environ and os.environ['TITLE']):
    title = os.environ['TITLE']
else:
    title = app.config['TITLE']

# Redis configurations
redis_server = os.environ['REDIS']
redis_port = int(os.environ.get('REDIS_PORT', '6379'))
redis_ssl = os.environ.get('REDIS_SSL', 'false').lower() == 'true'
redis_connect_timeout = int(os.environ.get('REDIS_CONNECT_TIMEOUT', '15'))
redis_socket_timeout = int(os.environ.get('REDIS_SOCKET_TIMEOUT', '15'))

logger.info("Redis configuration:")
logger.info("  Host:             %s", redis_server)
logger.info("  Port:             %s", redis_port)
logger.info("  SSL:              %s", redis_ssl)
logger.info("  Connect timeout:  %s", redis_connect_timeout)
logger.info("  Socket timeout:   %s", redis_socket_timeout)
logger.info("  Password set:     %s", "REDIS_PWD" in os.environ)

# Redis Connection
try:
    if "REDIS_PWD" in os.environ:
        logger.debug("Creating Redis connection WITH password (StrictRedis)")
        r = redis.StrictRedis(
            host=redis_server,
            port=redis_port,
            password=os.environ['REDIS_PWD'],
            ssl=redis_ssl,
            socket_connect_timeout=redis_connect_timeout,
            socket_timeout=redis_socket_timeout,
            decode_responses=False
        )
    else:
        logger.debug("Creating Redis connection WITHOUT password")
        r = redis.Redis(
            host=redis_server,
            port=redis_port,
            ssl=redis_ssl,
            socket_connect_timeout=redis_connect_timeout,
            socket_timeout=redis_socket_timeout,
            decode_responses=False
        )
    logger.info("Sending PING to Redis at %s:%s ...", redis_server, redis_port)
    r.ping()
    logger.info("Redis PING successful — connection established")
except redis.ConnectionError as e:
    logger.error("Failed to connect to Redis at %s:%s — %s", redis_server, redis_port, e)
    exit('Failed to connect to Redis, terminating.')
except redis.TimeoutError as e:
    logger.error("Timeout connecting to Redis at %s:%s — %s", redis_server, redis_port, e)
    exit('Timeout connecting to Redis, terminating.')
except Exception as e:
    logger.error("Unexpected error connecting to Redis at %s:%s — %s: %s", redis_server, redis_port, type(e).__name__, e)
    exit('Unexpected error connecting to Redis, terminating.')

# Change title to host name to demo NLB
if app.config['SHOWHOST'] == "true":
    title = socket.gethostname()

# Init Redis
if not r.get(button1): r.set(button1, 0)
if not r.get(button2): r.set(button2, 0)
logger.info("Redis initialized — vote keys set")


@app.route('/health')
def health():
    """Health check endpoint that verifies Redis connectivity."""
    try:
        r.ping()
        return 'OK', 200
    except Exception as e:
        logger.error("Health check failed — Redis error: %s: %s", type(e).__name__, e)
        return f'Redis unreachable: {e}', 503


@app.route('/', methods=['GET', 'POST'])
def index():

    if request.method == 'GET':

        # Get current values
        try:
            vote1 = r.get(button1).decode('utf-8')
            vote2 = r.get(button2).decode('utf-8')
        except Exception as e:
            logger.error("Redis GET failed: %s: %s", type(e).__name__, e)
            return f"Error reading from Redis: {e}", 500

        # Return index with values
        return render_template("index.html", value1=int(vote1), value2=int(vote2),
                               button1=button1, button2=button2, title=title)

    elif request.method == 'POST':

        if request.form['vote'] == 'reset':

            try:
                # Empty table and return results
                r.set(button1, 0)
                r.set(button2, 0)
                vote1 = r.get(button1).decode('utf-8')
                vote2 = r.get(button2).decode('utf-8')
            except Exception as e:
                logger.error("Redis RESET failed: %s: %s", type(e).__name__, e)
                return f"Error resetting votes in Redis: {e}", 500
            return render_template("index.html", value1=int(vote1), value2=int(vote2),
                                   button1=button1, button2=button2, title=title)

        else:

            try:
                # Insert vote result into DB
                vote = request.form['vote']
                r.incr(vote, 1)

                # Get current values
                vote1 = r.get(button1).decode('utf-8')
                vote2 = r.get(button2).decode('utf-8')
            except Exception as e:
                logger.error("Redis VOTE failed: %s: %s", type(e).__name__, e)
                return f"Error recording vote in Redis: {e}", 500

            # Return results
            return render_template("index.html", value1=int(vote1), value2=int(vote2),
                                   button1=button1, button2=button2, title=title)


if __name__ == "__main__":
    app.run()
