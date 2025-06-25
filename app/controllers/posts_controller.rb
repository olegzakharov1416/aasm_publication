class PostsController < ApplicationController
  before_action :set_post, only: [ :show, :edit, :update, :destroy, :verify_with_ai, :verify, :publish, :delete, :restore ]

  def index
    @posts = Post.active.order(created_at: :desc)
  end

  def show
  end

  def new
    @post = Post.new
  end

  def create
    @post = Post.new(post_params)

    if @post.save
      redirect_to @post, notice: "Пост успешно создан."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @post.update(post_params)
      @post.reset_state_after_edit!

      redirect_to @post, notice: "Пост успешно обновлен. Требуется повторная проверка."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.delete!
    redirect_to posts_url, notice: "Пост удален."
  end

  def verify_with_ai
    ai_service = AiVerificationService.new(@post)
    result = ai_service.verify

    if result[:success]
      if @post.verify_with_ai!
        redirect_to @post, notice: "Пост проверен ИИ: #{result[:message]}"
      else
        redirect_to @post, alert: "Не удалось обновить статус поста"
      end
    else
      redirect_to @post, alert: "Проверка ИИ не пройдена: #{result[:message]}"
    end
  end

  def verify
    if @post.verify!
      redirect_to @post, notice: "Пост проверен."
    else
      redirect_to @post, alert: "Не удалось проверить пост."
    end
  end

  def publish
    if @post.publish!
      redirect_to @post, notice: "Пост опубликован."
    else
      redirect_to @post, alert: "Не удалось опубликовать пост."
    end
  end

  def delete
    if @post.delete!
      redirect_to posts_url, notice: "Пост удален."
    else
      redirect_to @post, alert: "Не удалось удалить пост."
    end
  end

  def restore
    if @post.restore!
      redirect_to @post, notice: "Пост восстановлен."
    else
      redirect_to @post, alert: "Не удалось восстановить пост."
    end
  end

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:title, :content)
  end
end
