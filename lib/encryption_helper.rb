module EncryptionHelper
    def encrypt(text, key)
      # puts "encrypting #{text} with key #{key}"
      cipher = OpenSSL::Cipher::AES.new(256, :CBC)
      cipher.encrypt
      cipher.key = [key].pack('H*')
      encrypted = cipher.update(text) + cipher.final
      Base64.encode64(encrypted).strip
    end

    def decrypt(text, key)
      # puts "decrypting #{text} with key #{key}"
      decipher = OpenSSL::Cipher::AES.new(256, :CBC)
      decipher.decrypt
      decipher.key = [key].pack('H*')
      decrypted = Base64.decode64(text)
      decipher.update(decrypted) + decipher.final
    end
end
