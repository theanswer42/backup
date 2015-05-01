require File.join(File.dirname(__FILE__), "logger")
require File.join(File.dirname(__FILE__), "errors")

require 'aws-sdk'

module Backup
  class AmazonUploader
    # Where do I get the credentials from? ENV
    # By default, aws-sdk will look for: 
    # AWS_ACCESS_KEY_ID
    # AWS_SECRET_ACCESS_KEY
    # AWS_REGION
    attr_reader :vault_name
    def initialize(config)
      access_key_id = ENV["AWS_ACCESS_KEY_ID"]||""
      secret_access_key = ENV["AWS_SECRET_ACCESS_KEY"]||""
      region = ENV["AWS_REGION"]||""

      raise Backup::UploaderError.new("Credentials incomplete!") if access_key_id.empty? || secret_access_key.empty? || region.empty?
      
      @vault_name = config.aws["vault_name"]
      Aws.config.update(region: region, credentials: Aws::Credentials.new(access_key_id, secret_access_key))
      @glacier = Aws::Glacier::Client.new()
    end
    
    MAX_UPLOAD_SIZE = 8 * 1024 * 1024
    def upload_file(file_id, path, sha256sum)
      raise Backup::UploaderError.new("File #{path} size is zero") if File.size(path)==0

      # for now, we'll only support simple uploads
      file_hashes = compute_hashes(path, MAX_UPLOAD_SIZE)
      
      raise Backup::UploaderError.new("checksum mismatch on #{path}") if file_hashes[:linear_hash] != sha256sum
      
      if file_hashes[:hashes_for_transport].length > 1
        return multipart_upload(file_id, path, sha256sum, file_hashes)
      else
        response = @glacier.upload_archive(account_id: "-", vault_name: vault_name, checksum: file_hashes[:tree_hash], body: File.open(path, 'rb'), archive_description: file_id)
        raise Backup::UploaderError.new("No archive-id returned!  #{response.inspect}") unless response.archive_id
        raise Backup::UploaderError.new("checksum sent back does not match!") unless response.checksum == file_hashes[:tree_hash]
        return response.archive_id
      end
    end
    
    private
    def multipart_upload(file_id, path, sha256sum, file_hashes)
      part_hashes = file_hashes[:hashes_for_transport]
      
      response = @glacier.initiate_multipart_upload(account_id: '-', vault_name: vault_name, archive_description: file_id, part_size: MAX_UPLOAD_SIZE)
      upload_id = response.upload_id
      
      file_parts_for_upload(path, MAX_UPLOAD_SIZE) do |index, io, range|
        tree_hash = part_hashes[index].to_s
        response = @glacier.upload_multipart_part(account_id: '-', vault_name: vault_name, upload_id: upload_id, checksum: tree_hash, range: range, body: io)
        raise Backup::UploaderError.new("Hash mismatch for part: #{index}") unless tree_hash == response.checksum
      end

      response = @glacier.complete_multipart_upload(account_id: '-', vault_name: vault_name, upload_id: upload_id, archive_size: File.size(path), checksum: file_hashes[:tree_hash])
      
      return response.archive_id
    end


    def file_parts_for_upload(path, part_size)
      file = File.open(path, 'rb')
      index = 0
      range_start = 0
      file_size = File.size(path)
      while(data = file.read(part_size))
        size = [part_size, data.size].min
        range_end = range_start + size - 1
        range = "bytes #{range_start}-#{range_end}/#{file_size-1}"
        yield(index, StringIO.new(data), range)
        range_start += part_size
        index += 1
      end
    end

    # computes a linear and tree hash for the given file
    # will only load one meg of the file at a time.
    ONE_MB = 1 * 1024 * 1024
    def compute_hashes(path, part_size)
      file = File.open(path, 'rb')
      linear_hash = Digest::SHA256.new
      
      parts = []
      while(data = file.read(ONE_MB))
        linear_hash << data
        
        sha256sum = Digest::SHA256.new
        sha256sum << data
        parts << sha256sum
      end
      
      current_part_size = ONE_MB
      parts_for_transport = []
      next_parts = []

      while true
        parts_for_transport = parts if current_part_size == part_size
        break if parts.length == 1

        index = 0
        while(!((pair = parts.slice(index,2))||[]).empty?)
          if pair.size == 1
            next_parts << pair[0] 
            break
          end
          
          sha256sum = Digest::SHA256.new
          sha256sum << pair[0].digest
          sha256sum << pair[1].digest
          next_parts << sha256sum
          index += 2
        end
        
        parts = next_parts
        next_parts = []
        current_part_size = current_part_size * 2
      end
      {linear_hash: linear_hash.to_s, tree_hash: parts.first.to_s, hashes_for_transport: parts_for_transport}
    end
    
  end
end
