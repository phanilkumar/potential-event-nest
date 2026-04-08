module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_user!, only: [:register, :login]

      def register
        user = User.new(register_params)

        if user.save
          token = user.generate_jwt
          render json: { token: token, user: { id: user.id, name: user.name, email: user.email, role: user.role } }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def login
        user = User.find_by(email: params[:email])

        if user&.authenticate(params[:password])
          token = user.generate_jwt
          render json: { token: token, user: { id: user.id, name: user.name, email: user.email, role: user.role } }
        else
          if user
            render json: { error: "Invalid password" }, status: :unauthorized
          else
            render json: { error: "No account found with that email" }, status: :unauthorized
          end
        end
      end

      private

      def register_params
        params.permit(:name, :email, :password, :password_confirmation, :role, :phone)
      end
    end
  end
end
