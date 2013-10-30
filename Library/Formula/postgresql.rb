require 'formula'

class Postgresql < Formula
  homepage 'http://www.postgresql.org/'
  url 'http://ftp.postgresql.org/pub/source/v9.3.1/postgresql-9.3.1.tar.bz2'
  sha256 '8ea4a7a92a6f5a79359b02e683ace335c5eb45dffe7f8a681a9ce82470a8a0b8'

  option '32-bit'
  option 'no-perl', 'Build without Perl support'
  option 'no-tcl', 'Build without Tcl support'
  option 'enable-dtrace', 'Build with DTrace support'

  depends_on 'readline'
  depends_on 'libxml2'
  depends_on 'libxslt'
  depends_on 'ossp-uuid' => :recommended
  depends_on :python => :recommended

  conflicts_with 'postgres-xc',
    :because => 'postgresql and postgres-xc install the same binaries.'

  fails_with :clang do
    build 211
    cause 'Miscompilation resulting in segfault on queries'
  end

  # Fix uuid-ossp build issues: http://archives.postgresql.org/pgsql-general/2012-07/msg00654.php
  def patches
    DATA
  end

  def install
    ENV.libxml2

    args = %W[
      --disable-debug
      --prefix=#{prefix}
      --datadir=#{share}/#{name}
      --docdir=#{doc}
      --enable-thread-safety
      --without-gssapi
      --without-krb5
      --without-ldap
      --with-openssl
      --without-pam
      --with-libxml
      --with-libxslt
      --without-readline
    ]

    args << "--with-ossp-uuid" if build.with? 'ossp-uuid'
    args << "--with-python" if build.with? 'python'
    args << "--with-perl" unless build.include? 'no-perl'
    args << "--with-tcl" unless build.include? 'no-tcl'
    args << "--enable-dtrace" if build.include? 'enable-dtrace'
    
    if build.with? 'ossp-uuid'
      ENV.append 'CFLAGS', `uuid-config --cflags`.strip
      ENV.append 'LDFLAGS', `uuid-config --ldflags`.strip
      ENV.append 'LIBS', `uuid-config --libs`.strip
    end

    if build.build_32_bit?
      ENV.append 'CFLAGS', "-arch #{MacOS.preferred_arch}"
      ENV.append 'LDFLAGS', "-arch #{MacOS.preferred_arch}"
    end

    system "./configure", *args
    system "make install-world"
  end

  def caveats
    s = <<-EOS.undent
    initdb #{var}/postgres -E utf8    # create a database cluster
    postgres -D #{var}/postgres       # serve that database
    PGDATA=#{var}/postgres postgres   # …alternatively

    If builds of PostgreSQL 9 are failing and you have version 8.x installed,
    you may need to remove the previous version first. See:
      https://github.com/mxcl/homebrew/issues/issue/2510

    To migrate existing data from a previous major version (pre-9.3) of PostgreSQL, see:
      http://www.postgresql.org/docs/9.3/static/upgrading.html
    EOS

    s << "\n" << gem_caveats if MacOS.prefer_64_bit?
    return s
  end

  def gem_caveats; <<-EOS.undent
    When installing the postgres gem, including ARCHFLAGS is recommended:
      ARCHFLAGS="-arch x86_64" gem install pg

    To install gems without sudo, see the Homebrew wiki.
    EOS
  end

end


__END__
--- a/contrib/uuid-ossp/uuid-ossp.c	2012-07-30 18:34:53.000000000 -0700
+++ b/contrib/uuid-ossp/uuid-ossp.c	2012-07-30 18:35:03.000000000 -0700
@@ -9,6 +9,8 @@
  *-------------------------------------------------------------------------
  */

+#define _XOPEN_SOURCE
+
 #include "postgres.h"
 #include "fmgr.h"
 #include "utils/builtins.h"
