class KnotResolver < Formula
  desc "Minimalistic, caching, DNSSEC-validating DNS resolver"
  homepage "https://www.knot-resolver.cz"
  url "https://secure.nic.cz/files/knot-resolver/knot-resolver-2.4.0.tar.xz"
  sha256 "8c88c73dd50dad6f371bfc170f49cd374022e59f8005ac1fa6cd99764f72b4d1"
  head "https://gitlab.labs.nic.cz/knot/knot-resolver.git"

  bottle do
    sha256 "a455f229e3d2da2839a148f7904fd87b4c35d800c602c4fd160354c8b037988f" => :high_sierra
    sha256 "75f2dfe6a52d014a1c3a3523656fed24d64cee4e66e1ba76c5b9a6367a71fec3" => :sierra
    sha256 "904106071027db6c61b3fbbf2cbd85425d6ed40a1a7437f911cc9bb219df2c06" => :el_capitan
  end

  option "without-nettle", "Compile without DNS cookies support"
  option "with-hiredis", "Compile with Redis cache storage support"
  option "with-libmemcached", "Compile with memcached cache storage support"

  depends_on "cmocka" => :build
  depends_on "pkg-config" => :build
  depends_on "gnutls"
  depends_on "knot"
  depends_on "luajit"
  depends_on "libuv"
  depends_on "lmdb"
  depends_on "nettle" => :recommended
  depends_on "hiredis" => :optional
  depends_on "libmemcached" => :optional

  def install
    # Since we don't run `make install` or `make etc-install`, we need to
    # install root.hints manually before running `make check`.
    cp "etc/root.hints", buildpath
    (etc/"kresd").install "root.hints"

    %w[all lib-install daemon-install client-install modules-install
       check].each do |target|
      system "make", target, "PREFIX=#{prefix}", "ETCDIR=#{etc}/kresd"
    end

    cp "etc/config.personal", "config"
    inreplace "config", /^\s*user\(/, "-- user("
    (etc/"kresd").install "config"

    (etc/"kresd").install "etc/root.hints"

    (buildpath/"root.keys").write(root_keys)
    (var/"kresd").install "root.keys"
  end

  # DNSSEC root anchor published by IANA (https://www.iana.org/dnssec/files)
  def root_keys; <<~EOS
    . IN DS 19036 8 2 49aac11d7b6f6446702e54a1607371607a1a41855200fd2ce1cdde32f24e8fb5
    . IN DS 20326 8 2 e06d44b80b8f1d39a95c0b0d7c65d08458e880409bbc683457104237c7f8ec8d
  EOS
  end

  plist_options :startup => true

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>WorkingDirectory</key>
      <string>#{var}/kresd</string>
      <key>RunAtLoad</key>
      <true/>
      <key>ProgramArguments</key>
      <array>
        <string>#{sbin}/kresd</string>
        <string>-c</string>
        <string>#{etc}/kresd/config</string>
      </array>
      <key>StandardInPath</key>
      <string>/dev/null</string>
      <key>StandardOutPath</key>
      <string>/dev/null</string>
      <key>StandardErrorPath</key>
      <string>#{var}/log/kresd.log</string>
    </dict>
    </plist>
  EOS
  end

  test do
    system sbin/"kresd", "--version"
  end
end
