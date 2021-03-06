require "authentic/version"
require "authentic/clipboard"
require "thor"
require "keychain"
require "rotp"
require "colorize"
require "ostruct"
require "json"
require "openssl"
require "base64"

module Authentic
  class CLI < Thor
    package_name "Authentic"
    default_task :generate

    desc "add NAME SECRET_KEY [SERVICE]", "Add a new TOTP key"
    def add(name, secret_key, service = nil)
      params = {
        label: "authentic gem",
        account:  name,
        service:  service || name,
        password: secret_key,
      }

      begin
        item = Keychain.generic_passwords.create(params)
      rescue => e
        message = e.message
      end

      unless item.nil?
        say "\u2713".colorize(:green) + " Service #{name.colorize(:green)} added to keychain"
      else
        say "\u2717".colorize(:red) + " Couldn't add service #{name.colorize(:red)}..."
        say "Error: #{message}" unless message.nil?
      end
    end

    desc "delete NAME", "Delete a TOTP key"
    option :force, default: false, type: :boolean, aliases: '-f'
    def delete(name)
      item = Keychain.generic_passwords.where(label: "authentic gem", account: name).first
      unless item
        return say "\u2717".colorize(:red) + " Couldn't find service #{name.colorize(:red)}..."
      end
      if options[:force] || yes?("Do you want to permanently delete #{name.colorize(:green)}?")
        item.delete
        say "\u2713".colorize(:green) + " Service #{name.colorize(:green)} deleted from keychain"
      else
        say "Leaving service #{name.colorize(:green)} in keychain"
      end
    end

    CLOCKS = {
      0 => "🌕",
      7 => "🌖",
      14 => "🌗",
      21 => "🌘",
      28 => "🌑",
    }

    desc "export", "Export TOTP secret keys"
    option 'qr', default: false, type: :boolean, aliases: '-q'
    def export
      keys = Keychain
        .generic_passwords
        .where(label: "authentic gem")
        .all.map do |key|
          secret = key.password.gsub(/=*$/, '')
          totp = ROTP::TOTP.new(secret)
          OpenStruct.new(
            secret:  secret,
            name:    key.attributes[:account],
            service: key.attributes[:service]
          )
        end.sort_by { |k| [k.service, k.name] }

      if options['qr']
        keys.each do |key|
          puts "#{key.service} - #{key.name}\n"
          puts `qrencode 'otpauth://totp/#{key.name}?issuer=#{key.service}&secret=#{key.secret}' -s 5 -o - | ~/.iterm2/imgcat`
        end
      else
        data = keys.map(&:to_h).to_json

        password = ask "Please enter a password for exported data:", echo: false
        return if password.empty?

        salt = OpenSSL::Random.random_bytes(32)
        cipher = OpenSSL::Cipher::AES256.new :CBC
        cipher.encrypt
        cipher.key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(password, salt, 20000, 32)
        cipher.iv = salt

        cipher_text = cipher.update(data)
        cipher_text << cipher.final

        puts [salt, cipher_text].map { |part| Base64.strict_encode64(part) }.join(':')
      end
    end

    desc "import DATA", "Import TOTP secret keys"
    def import(data)
      password = ask "Please enter a password for exported data:", echo: false
      return if password.empty?

      salt, cipher_text = data.split(':').map { |part| Base64.strict_decode64(part) }

      cipher = OpenSSL::Cipher::AES256.new :CBC
      cipher.decrypt
      cipher.iv = salt
      cipher.key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(password, salt, 20000, 32)

      text = cipher.update(cipher_text)
      text << cipher.final

      keys = JSON.parse(text)

      keys.each do |key|
        add(key['name'], key['secret'], key['service'])
      end
    end

    desc "generate", "Generate TOTP codes"
    option 'skip-copy', default: false, type: :boolean, aliases: '-s'
    def generate
      now  = Time.now
      keys = Keychain
              .generic_passwords
              .where(label: "authentic gem")
              .all.map do |key|
                secret = key.password.gsub(/=*$/, '')
                totp = ROTP::TOTP.new(secret)
                OpenStruct.new(
                  secret:  secret,
                  code:    totp.at(now),
                  name:    key.attributes[:account],
                  service: key.attributes[:service],
                  remain:  now.utc.to_i % totp.interval
                )
              end.sort_by { |k| [k.service, k.name] }

      table = keys.each_with_index.map do |key, idx|
        number = (idx + 1).to_s.rjust(keys.size.to_s.size, ' ')
        service_prefix = "#{key.service} - " if key.service && key.service != key.name
        [
          number.colorize(:red),
          key.code.colorize(:green),
          "#{service_prefix}#{key.name}",
          CLOCKS[7 * (key.remain / 7)].colorize(:blue)
        ]
      end

      print_table(table.to_a)

      unless options['skip-copy'] || keys.size == 0
        if keys.size > 1
          prompt = "\nWhich key should I copy?"
          prompt += " [1-#{keys.size}, leave empty to exit]"
          response = ask prompt
          return if response.empty?
          idx = response.to_i - 1
          key = keys[idx]
        else
          key = keys.first
        end
        Clipboard.pbcopy key.code
        say "\nKey for account #{key.name.colorize(:green)} copied to clipboard"
      end
    end
  end
end
