class AiVerificationService
  def initialize(post)
    @post = post
    @client = OpenAI::Client.new(access_token: ENV["CHAT_GPT_TOKEN"])
  end

  def verify
    begin
      response = @client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [
            {
              role: "system",
              content: "Ты модератор контента.
                        Пост должен не содержать спама, рекламы или неприемлемого контента и соответствовать законам РФ и правилам российского интернета.
                        Проверь следующий текст на соответствие законодательству Российской Федерации, включая:
                        1. Федеральные законы:
                        № 149-ФЗ «Об информации, информационных технологиях и о защите информации»
                        № 114-ФЗ «О противодействии экстремистской деятельности»
                        № 436-ФЗ «О защите детей от информации, причиняющей вред их здоровью и развитию»
                        Закон о фейках, дискредитации ВС РФ и «СВО»
                        2. Требования Роскомнадзора:
                        Запрещённая информация: призывы к насилию, самоубийству, распространение наркотиков, порнография, ЛГБТ-пропаганда, фейки, оскорбления госсимволов, экстремизм.
                        3. Упоминание запрещённых в России ресурсов и организаций:
                        Соцсети и компании, признанные экстремистскими (например, Meta*, Facebook*, Instagram*)
                        Сайты, заблокированные в РФ (например, Navalny.com*, Ходорковский Live*, Tor, ProtonVPN и пр.)
                        Торрент-сайты, даркнет, инструкции по обходу блокировок
                        Формат ответа:
                        Укажи, есть ли нарушения.
                        Если есть — процитируй проблемные фрагменты, уточни, какие именно законы или нормы они нарушают.
                        Если нарушений нет — напиши: «Нарушений не выявлено».
                        Дай ответ в формате JSON: {\"approved\": true/false, \"reason\": \"причина одобрения или отклонения развернуто\"}"
            },
            {
              role: "user",
              content: "Заголовок: #{@post.title}\n\nСодержание: #{@post.content}"
            }
          ],
          temperature: 0.3
        }
      )

      result = parse_ai_response(response.dig("choices", 0, "message", "content"))

      if result[:approved]
        { success: true, message: "Контент одобрен ИИ: #{result[:reason]}" }
      else
        { success: false, message: "Контент отклонен ИИ: #{result[:reason]}" }
      end
    rescue => e
      Rails.logger.error "OpenAI API Error: #{e.message}"
      { success: false, message: "Ошибка при проверке ИИ: #{e.message}" }
    end
  end

  private

  def parse_ai_response(response_text)
    begin
      json_match = response_text.match(/\{.*\}/m)
      if json_match
        parsed = JSON.parse(json_match[0])
        {
          approved: parsed["approved"] == true,
          reason: parsed["reason"] || "Не указана причина"
        }
      else
        if response_text.downcase.include?("одобрен") || response_text.downcase.include?("approved")
          { approved: true, reason: "Контент соответствует стандартам" }
        else
          { approved: false, reason: "Контент не соответствует стандартам" }
        end
      end
    rescue JSON::ParserError
      if response_text.downcase.include?("одобрен") || response_text.downcase.include?("approved")
        { approved: true, reason: "Контент соответствует стандартам" }
      else
        { approved: false, reason: "Контент не соответствует стандартам" }
      end
    end
  end
end
