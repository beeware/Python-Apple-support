###########################################################################
# Common tests
###########################################################################
import importlib
import os

from .utils import assert_


def test_bootstrap_modules():
    "All the bootstrap modules are importable"
    missing = []

    # The list of bootstrap modules that don't have explicit tests.
    for module in [
        '_abc',
        '_codecs',
        '_collections',
        '_functools',
        '_io',
        '_locale',
        '_operator',
        '_signal',
        '_sre',
        '_stat',
        '_symtable',
        '_thread',
        '_tracemalloc',
        '_weakref',
        'atexit',
        'errno',
        'faulthandler',
        'itertools',
        'posix',
        'pwd',
        'time',
    ]:
        try:
            importlib.import_module(module)
        except ModuleNotFoundError:
            missing.append(module)

    assert_(len(missing) == 0, msg=f"Missing bootstrap modules: {', '.join(str(m) for m in missing)}")


def test_stdlib_modules():
    "All the stdlib modules exist"
    missing = []
    for module in [
        "_asyncio",
        "_bisect",
        "_codecs_cn",
        "_codecs_hk",
        "_codecs_iso2022",
        "_codecs_jp",
        "_codecs_kr",
        "_codecs_tw",
        "_contextvars",
        "_csv",
        "_datetime",
        "_heapq",
        "_json",
        "_lsprof",
        "_multibytecodec",
        "_multiprocessing",
        "_opcode",
        "_pickle",
        "_posixsubprocess",
        "_queue",
        "_random",
        "_socket",
        "_statistics",
        "_struct",
        "_uuid",
        "array",
        "binascii",
        "cmath",
        "fcntl",
        "grp",
        "math",
        "mmap",
        "resource",
        "select",
        "syslog",
        "termios",
        "unicodedata",
        "zlib",
        # Scheduled for deprecation
        "_crypt",
        "audioop",
    ]:
        try:
            importlib.import_module(module)
        except ModuleNotFoundError:
            missing.append(module)

    assert_(len(missing) == 0, msg=f"Missing stdlib modules: {', '.join(str(m) for m in missing)}")


def test_bzip2():
    "BZip2 compression with the bz2 module works"
    import bz2

    data = bz2.compress(b"Hello world")
    assert_(
        data == b"BZh91AY&SY\x059\x88u\x00\x00\x00\x95\x80@\x00\x00@\x06\x04"
        b'\x90\x80 \x00"\x06\x9bHC\x02\x1a|\n\xa1<]\xc9\x14\xe1B@\x14\xe6!\xd4'
    )


def test_ctypes():
    "The FFI module has been compiled, and ctypes works on ObjC objects"
    from rubicon.objc import ObjCClass

    NSURL = ObjCClass("NSURL")

    base = NSURL.URLWithString("https://beeware.org/")
    full = NSURL.URLWithString("contributing", relativeToURL=base)
    absolute = full.absoluteURL
    assert_(absolute.description == "https://beeware.org/contributing")

def test_dbm():
    "The DBM module is accessible"
    import dbm

    cache_name = f'{os.path.dirname(__file__)}/dbm'
    try:
        with dbm.open(cache_name, 'c') as db:
            db['hello'] = 'world'

            assert_(db['hello'] == b'world')
    finally:
        os.remove(f'{cache_name}.db')


def test_dbm_dumb():
    "The dumb DBM module has been compiled and works"
    from dbm import dumb as ddbm

    cache_name = f'{os.path.dirname(__file__)}/ddbm'
    try:
        with ddbm.open(cache_name, 'c') as db:
            db['hello'] = 'world'

            assert_(db['hello'] == b'world')
    finally:
        os.remove(f'{cache_name}.bak')
        os.remove(f'{cache_name}.dat')
        os.remove(f'{cache_name}.dir')


def test_dbm_ndbm():
    "The ndbm DBM module has been compiled and works"
    from dbm import ndbm

    cache_name = f'{os.path.dirname(__file__)}/ndbm'
    try:
        with ndbm.open(cache_name, 'c') as db:
            db['hello'] = 'world'

            assert_(db['hello'] == b'world')
    finally:
        os.remove(f'{cache_name}.db')


def test_decimal():
    "The decimal module works"
    from decimal import Decimal, getcontext

    getcontext().prec = 28
    assert str(Decimal(1) / Decimal(7)) == "0.1428571428571428571428571429"


def test_hashlib():
    "Hashlib can compute hashes"
    import hashlib

    algorithms = {
        "md5": "3e25960a79dbc69b674cd4ec67a72c62",
        "sha1": "7b502c3a1f48c8609ae212cdfb639dee39673f5e",
        "sha224": "ac230f15fcae7f77d8f76e99adf45864a1c6f800655da78dea956112",
        "sha256": ("64ec88ca00b268e5ba1a35678a1b5316d212f4f366b2477232534a8aeca37f3c"),
        "sha384": (
            "9203b0c4439fd1e6ae5878866337b7c532acd6d9260150c80318e8ab8c27ce33"
            "0189f8df94fb890df1d298ff360627e1"
        ),
        "sha512": (
            "b7f783baed8297f0db917462184ff4f08e69c2d5e5f79a942600f9725f58ce1f"
            "29c18139bf80b06c0fff2bdd34738452ecf40c488c22a7e3d80cdf6f9c1c0d47"
        ),
        "blake2b": (
            "6ff843ba685842aa82031d3f53c48b66326df7639a63d128974c5c14f31a0f33"
            "343a8c65551134ed1ae0f2b0dd2bb495dc81039e3eeb0aa1bb0388bbeac29183"
        ),
        "blake2s": "619a15b0f4dd21ef4bd626a9146af64561caf1325b21bccf755e4d7fbc31a65f",
        "sha3_224": "3b8570ec1335c461747d016460ff91cb41fad08051911c50dd8e1995",
        "sha3_256": (
            "369183d3786773cef4e56c7b849e7ef5f742867510b676d6b38f8e38a222d8a2"
        ),
        "sha3_384": (
            "ff3917192427ea1aa7f3ad47ac10152d179af30126c52835ee8dc7e6ea12aed9"
            "1ad91b316e15c3b250469ef17a03e529"
        ),
        "sha3_512": (
            "e2e1c9e522efb2495a178434c8bb8f11000ca23f1fd679058b7d7e141f0cf343"
            "3f94fc427ec0b9bebb12f327a3240021053db6091196576d5e6d9bd8fac71c0c"
        ),
        "shake_128": (
            40,
            "c1301df86b1dc67ce3b5a067dc9b47affca8caa08f41d1efa614cea56f526897"
            "d61ded8ab01421f1",
        ),
        "shake_256": (
            40,
            "20740b4c7a7997765e9cc254b44a1589e60849be0fe70b68a6fb732415edaa13"
            "3bb6eb7825ffa531",
        ),
    }
    for algorithm, details in algorithms.items():
        try:
            length, expected = details
            digest_args = {"length": length}
        except ValueError:
            expected = details
            digest_args = {}
        msg = getattr(hashlib, algorithm)()
        msg.update(b"Hello world")
        assert_(
            msg.hexdigest(**digest_args) == expected,
            msg=f"{algorithm} digest was {msg.hexdigest(**digest_args)}",
        )


def test_sqlite3():
    "The sqlite3 module works"
    import sqlite3

    conn = sqlite3.connect(":memory:")
    try:
        cursor = conn.cursor()

        cursor.execute(
            "CREATE TABLE stonks (date text, symbol text, qty real, price real)"
        )
        cursor.execute("INSERT INTO stonks VALUES ('2022-05-04', 'JEDI', 10, 2.50)")
        cursor.execute("INSERT INTO stonks VALUES ('2022-05-04', 'SITH', 2, 6.66)")
        conn.commit()

        assert_(
            list(cursor.execute("SELECT * FROM stonks ORDER BY symbol DESC"))
            == [("2022-05-04", "SITH", 2.0, 6.66), ("2022-05-04", "JEDI", 10.0, 2.5)]
        )
    finally:
        conn.close()


def test_ssl():
    "The SSL modules has been compiled"
    import ssl

    # Result doesn't really matter; we just need to be able to invoke
    # a method whose implementation is in the C module
    ssl.get_default_verify_paths()


def test_tempfile():
    "A tempfile can be written"
    import tempfile

    msg = b"I've watched C-beams glitter in the dark near the Tannhauser Gate."
    with tempfile.TemporaryFile() as f:
        # Write content to the temp file
        f.write(msg)

        # Reset the file pointer to 0 and read back the content
        f.seek(0)
        assert_(f.read() == msg)


XML_DOCUMENT = """<?xml version="1.0"?>
<data>
    <device name="iPhone">
        <os>iOS</os>
        <type>phone</type>
    </device>
    <device name="macBook">
        <os>macOS</os>
        <type>laptop</type>
    </device>
</data>
"""


def test_xml_elementtree():
    "The elementtree XML parser works"
    import xml.etree.ElementTree as ET

    root = ET.fromstring(XML_DOCUMENT)
    assert_(
        [(child.tag, child.attrib["name"]) for child in root]
        == [("device", "iPhone"), ("device", "macBook")]
    )


def test_xml_expat():
    "The expat XML parser works"
    from xml.parsers.expat import ParserCreate

    starts = []

    def start_element(name, attrs):
        starts.append(name)

    parser = ParserCreate()
    parser.StartElementHandler = start_element
    parser.Parse(XML_DOCUMENT)

    assert_(starts == ["data", "device", "os", "type", "device", "os", "type"])


def test_xz():
    "XZ compression with the lzma module works"
    import lzma

    data = lzma.compress(b"Hello world")
    assert_(
        data == b"\xfd7zXZ\x00\x00\x04\xe6\xd6\xb4F\x02\x00!\x01\x16\x00\x00\x00t/"
        b"\xe5\xa3\x01\x00\nHello world\x00\x00\xbfVw\xd4\xb9\xf2\xa5\xf4\x00"
        b"\x01#\x0b\xc2\x1b\xfd\t\x1f\xb6\xf3}\x01\x00\x00\x00\x00\x04YZ"
    )


def test_zoneinfo():
    "Zoneinfo database is available"
    from zoneinfo import ZoneInfo
    from datetime import datetime

    dt = datetime(2022, 5, 4, 13, 40, 42, tzinfo=ZoneInfo("Australia/Perth"))
    assert_(str(dt) == "2022-05-04 13:40:42+08:00")
