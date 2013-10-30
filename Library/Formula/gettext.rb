require 'formula'

class Gettext < Formula
  homepage 'http://www.gnu.org/software/gettext/'
  url 'http://ftpmirror.gnu.org/gettext/gettext-0.18.3.1.tar.gz'
  mirror 'http://ftp.gnu.org/gnu/gettext/gettext-0.18.3.1.tar.gz'
  sha256 '0d8f9a33531b77776b3dc473e7940019ca19bfca5b4c06db6e96065eeb07245d'

  bottle do
    sha1 '2aa3a9363106fff9c7adf87527a60a4351dbc6e1' => :mountain_lion
    sha1 '59cc5083d0cc6053ecbb857146730ed8953357e8' => :lion
    sha1 'd1c2af7389a8234954d1093c4beb4c6484e6e250' => :snow_leopard
  end

  option 'with-examples', 'Keep example files'

  def install
    ENV.libxml2
    ENV.universal_binary if build.universal?

    system "./configure", "--disable-dependency-tracking",
                          "--disable-debug",
                          "--prefix=#{prefix}",
                          "--with-included-gettext",
                          "--with-included-glib",
                          "--with-included-libcroco",
                          "--with-included-libunistring",
                          "--with-emacs",
                          "--disable-java",
                          "--disable-csharp",
                          # Don't use VCS systems to create these archives
                          "--without-git",
                          "--without-cvs"
    system "make"
    ENV.deparallelize # install doesn't support multiple make jobs
    system "make install"
  end
end
