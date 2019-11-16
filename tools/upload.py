import os
import sys
import threading

from botocore.exceptions import ClientError
import boto3

from argparse import ArgumentParser


class Progress:
    def __init__(self, index, count, filename):
        self.index = index
        self.count = count
        self.filename = os.path.basename(filename)
        self.size = float(os.path.getsize(filename))
        self.seen_so_far = 0
        self.lock = threading.Lock()

    def __call__(self, bytes_amount):
        # To simplify we'll assume this is hooked up
        # to a single filename.
        with self.lock:
            self.seen_so_far += bytes_amount
            percentage = (self.seen_so_far / self.size) * 100
            sys.stdout.write(
                "\r[%s/%s] %s %s/%s (%.2f%%)" % (
                    self.index, self.count, self.filename,
                    self.seen_so_far, int(self.size),
                    percentage))
            sys.stdout.flush()


def upload(build, directory, s3_client):
    filenames = []
    for filename in os.listdir(directory):
        full_filename = os.path.join(directory, filename)
        if filename.endswith('-support.%s.tar.gz' % build):
            filenames.append((filename, full_filename))

    for i, (filename, full_filename) in enumerate(filenames):
            py, version, platform, remainder = filename.split('-')
            sys.stdout.write("[%s/%s] %s..." % (i + 1, len(filenames), filename))
            sys.stdout.flush()
            with open(full_filename, 'rb') as data:
                s3_client.upload_fileobj(
                    data,
                    'briefcase-support',
                    'python/%s/%s/%s' % (
                        version,
                        platform,
                        filename
                    ),
                    Callback=Progress(i+1, len(filenames), full_filename)
                )
            print()


def main():
    parser = ArgumentParser()
    parser.add_argument(
        '--directory', '-d', default='dist', dest='directory',
        help='Specify the directory containing artefacts.',
    )
    parser.add_argument('tag', metavar='tag', help='Build tag to upload.')
    options = parser.parse_args()

    # Load sensitive environment variables from a .env file
    try:
        with open('.env') as envfile:
            for line in envfile:
                if line.strip() and not line.startswith('#'):
                    key, value = line.strip().split('=', 1)
                    os.environ.setdefault(key.strip(), value.strip())
    except FileNotFoundError:
        pass

    try:
        aws_session = boto3.session.Session(
            region_name=os.environ['AWS_REGION'],
            aws_access_key_id=os.environ['AWS_ACCESS_KEY_ID'],
            aws_secret_access_key=os.environ['AWS_SECRET_ACCESS_KEY'],
        )
        s3_client = aws_session.client('s3')

        print("Uploading %s support files..." % options.tag)
        upload(options.tag, options.directory, s3_client)
    except KeyError as e:
        print("AWS environment variable %s not found" % e)
        sys.exit(1)


if __name__ == '__main__':
    main()
