require 'formula'

class Py2cairo < Formula
  homepage 'http://cairographics.org/pycairo/'
  url 'http://cairographics.org/releases/py2cairo-1.10.0.tar.bz2'
  sha1 '2efa8dfafbd6b8e492adaab07231556fec52d6eb'

  depends_on 'pkg-config' => :build
  depends_on 'cairo'
  depends_on :python


  fails_with :llvm do
    build 2336
    cause "The build script will set -march=native which llvm can't accept"
  end

  def install
    python do
      ENV['CFLAGS'] = "-I#{python.prefix}/include/python2.7"
      ENV['LINKFLAGS'] = "-L#{python.libdir}"
      system "./waf", "configure", "--prefix=#{prefix}", "--nopyc", "--nopyo"
      system "./waf", "install"
    end
  end

  def caveats
    python.standard_caveats if python
  end

end
