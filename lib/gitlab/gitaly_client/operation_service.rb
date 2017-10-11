module Gitlab
  module GitalyClient
    class OperationService
      def initialize(repository)
        @gitaly_repo = repository.gitaly_repository
        @repository = repository
      end

      def rm_tag(tag_name, user)
        request = Gitaly::UserDeleteTagRequest.new(
          repository: @gitaly_repo,
          tag_name: GitalyClient.encode(tag_name),
          user: Util.gitaly_user(user)
        )

        response = GitalyClient.call(@repository.storage, :operation_service, :user_delete_tag, request)

        if pre_receive_error = response.pre_receive_error.presence
          raise Gitlab::Git::HooksService::PreReceiveError, pre_receive_error
        end
      end

      def add_tag(tag_name, user, target, message)
        request = Gitaly::UserCreateTagRequest.new(
          repository: @gitaly_repo,
          user: Util.gitaly_user(user),
          tag_name: GitalyClient.encode(tag_name),
          target_revision: GitalyClient.encode(target),
          message: GitalyClient.encode(message.to_s)
        )

        response = GitalyClient.call(@repository.storage, :operation_service, :user_create_tag, request)
        if pre_receive_error = response.pre_receive_error.presence
          raise Gitlab::Git::HooksService::PreReceiveError, pre_receive_error
        elsif response.exists
          raise Gitlab::Git::Repository::TagExistsError
        end

        Util.gitlab_tag_from_gitaly_tag(@repository, response.tag)
      rescue GRPC::FailedPrecondition => e
        raise Gitlab::Git::Repository::InvalidRef, e
      end

      def user_create_branch(branch_name, user, start_point)
        request = Gitaly::UserCreateBranchRequest.new(
          repository: @gitaly_repo,
          branch_name: GitalyClient.encode(branch_name),
          user: Util.gitaly_user(user),
          start_point: GitalyClient.encode(start_point)
        )
        response = GitalyClient.call(@repository.storage, :operation_service,
          :user_create_branch, request)
        if response.pre_receive_error.present?
          raise Gitlab::Git::HooksService::PreReceiveError.new(response.pre_receive_error)
        end

        branch = response.branch
        return nil unless branch

        target_commit = Gitlab::Git::Commit.decorate(@repository, branch.target_commit)
        Gitlab::Git::Branch.new(@repository, branch.name, target_commit.id, target_commit)
      end

      def user_delete_branch(branch_name, user)
        request = Gitaly::UserDeleteBranchRequest.new(
          repository: @gitaly_repo,
          branch_name: GitalyClient.encode(branch_name),
          user: Util.gitaly_user(user)
        )

        response = GitalyClient.call(@repository.storage, :operation_service, :user_delete_branch, request)

        if pre_receive_error = response.pre_receive_error.presence
          raise Gitlab::Git::HooksService::PreReceiveError, pre_receive_error
        end
      end
    end
  end
end
