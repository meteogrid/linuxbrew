require 'formula'

class Openssl < Formula
  homepage 'http://openssl.org'
  url 'http://openssl.org/source/openssl-1.0.1e.tar.gz'
  mirror 'http://mirrors.ibiblio.org/openssl/source/openssl-1.0.1e.tar.gz'
  sha256 'f74f15e8c8ff11aa3d5bb5f276d202ec18d7246e95f961db76054199c69c1ae3'

  def install
    args = %W[./Configure
               --prefix=#{prefix}
               --openssldir=#{openssldir}
               zlib-dynamic
               shared
             ]

    system "perl", *args

    ENV.deparallelize
    system "make", "depend" if MacOS.prefer_64_bit?
    system "make"
    system "make", "test"
    system "make", "install", "MANDIR=#{man}", "MANSUFFIX=ssl"
  end

  def setup_makedepend_shim
    path = buildpath/"brew/makedepend"
    path.write <<-EOS.undent
      #!/bin/sh
      exec "#{ENV.cc}" -M "$@"
      EOS
    path.chmod 0755
    ENV.prepend_path 'PATH', path.parent
  end

  def openssldir
    etc/"openssl"
  end

  def cert_pem
    openssldir/"cert.pem"
  end

  def osx_cert_pem
    openssldir/"osx_cert.pem"
  end

  def write_pem_file
    system "security find-certificate -a -p /Library/Keychains/System.keychain > '#{osx_cert_pem}.tmp'"
    system "security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain >> '#{osx_cert_pem}.tmp'"
    system "mv", "-f", "#{osx_cert_pem}.tmp", osx_cert_pem
  end

  def post_install
    openssldir.mkpath

    if cert_pem.exist?
      write_pem_file
    else
      cert_pem.unlink if cert_pem.symlink?
      write_pem_file
      openssldir.install_symlink 'osx_cert.pem' => 'cert.pem'
    end
  end
end
