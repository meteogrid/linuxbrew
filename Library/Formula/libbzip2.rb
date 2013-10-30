require 'formula'

class Libbzip2 < Formula
  homepage 'http://www.bzip.org/'
  url 'http://www.bzip.org/1.0.6/bzip2-1.0.6.tar.gz'
  sha1 '3f89f861209ce81a6bab1fd1998c0ef311712002'

  def install
    system "make install PREFIX=#{prefix}"
  end
end
