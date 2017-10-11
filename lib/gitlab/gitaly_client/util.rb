module Gitlab
  module GitalyClient
    module Util
      class << self
        def repository(repository_storage, relative_path, gl_repository)
          Gitaly::Repository.new(
            storage_name: repository_storage,
            relative_path: relative_path,
            gl_repository: gl_repository,
            git_object_directory: Gitlab::Git::Env['GIT_OBJECT_DIRECTORY'].to_s,
            git_alternate_object_directories: Array.wrap(Gitlab::Git::Env['GIT_ALTERNATE_OBJECT_DIRECTORIES'])
          )
        end

        def gitaly_user(gitlab_user)
          return unless gitlab_user

          Gitaly::User.new(
            gl_id: Gitlab::GlId.gl_id(gitlab_user),
            name: GitalyClient.encode(gitlab_user.name),
            email: GitalyClient.encode(gitlab_user.email)
          )
        end

        def gitlab_tag_from_gitaly_tag(repository, gitaly_tag)
          if gitaly_tag.target_commit.present?
            commit = Gitlab::Git::Commit.decorate(repository, gitaly_tag.target_commit)
          end

          Gitlab::Git::Tag.new(
            repository,
            Gitlab::EncodingHelper.encode!(gitaly_tag.name.dup),
            gitaly_tag.id,
            commit,
            Gitlab::EncodingHelper.encode!(gitaly_tag.message.chomp)
          )
        end
      end
    end
  end
end
