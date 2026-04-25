defmodule MinuteiroWeb.TemplateEditorLive do
  use MinuteiroWeb, :live_view

  alias Minuteiro.Documents

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Documents.get_template(socket.assigns.current_scope, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Modelo nao encontrado.")
         |> push_navigate(to: ~p"/")}

      template ->
        {:ok,
         assign_editor_state(socket, template, %{},
           save_state: :saved,
           editor_revision: 0,
           reset_ai_prompts: true
         )}
    end
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:template_form, template_form(assigns.template))
      |> assign(:editor_variable_names, editor_variable_names(assigns.template_variables))

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6">
        <div class="overflow-hidden rounded-[2rem] border border-base-300/70 bg-base-100 shadow-[0_28px_90px_-50px_rgba(15,23,42,0.55)]">
          <div class="border-b border-base-300/70 px-6 py-6 sm:px-8">
            <div class="flex flex-wrap items-start justify-between gap-4">
              <div class="space-y-3">
                <.link
                  navigate={~p"/"}
                  class="inline-flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.18em] text-base-content/45 transition hover:text-orange-500"
                >
                  <.icon name="hero-arrow-left" class="size-4" /> Voltar ao dashboard
                </.link>
                <h1 class="text-3xl font-semibold tracking-tight text-balance sm:text-4xl">
                  {@template.title}
                </h1>
                <p class="max-w-2xl text-sm leading-7 text-base-content/70 sm:text-base">
                  {@template.description ||
                    "Edite o conteudo bruto do template, ajuste as respostas dinamicas e acompanhe a compilacao do documento em tempo real."}
                </p>
              </div>

              <div class="grid gap-3 sm:min-w-72 sm:grid-cols-2">
                <div class="rounded-3xl border border-base-300/70 bg-base-200/50 px-4 py-3 text-sm shadow-inner shadow-base-300/50">
                  <p class="text-xs uppercase tracking-[0.18em] text-base-content/45">
                    Campos ativos
                  </p>
                  <p class="mt-2 text-2xl font-semibold">{length(@variables)}</p>
                </div>

                <div
                  id="template-save-status"
                  class={[
                    "rounded-3xl border px-4 py-3 text-sm shadow-inner",
                    save_state_container_class(@save_state)
                  ]}
                >
                  <p class="text-xs uppercase tracking-[0.18em] text-base-content/45">Estado</p>
                  <p class="mt-2 text-sm font-semibold">{save_state_label(@save_state)}</p>
                  <p class="mt-1 text-xs leading-5 text-base-content/60">
                    {save_state_help(@save_state)}
                  </p>
                </div>
              </div>
            </div>
          </div>

          <div class="px-6 py-6 sm:px-8">
            <.form
              for={@template_form}
              id="template-editor-form"
              phx-change="update_template"
              phx-submit="save"
            >
              <.input
                field={@template_form[:title]}
                type="text"
                label="Titulo"
                class="w-full rounded-2xl border border-base-300 bg-base-100 px-4 py-3 focus:border-orange-400 focus:outline-none"
              />

              <.input
                field={@template_form[:description]}
                type="textarea"
                label="Descricao"
                rows="4"
                class="w-full rounded-2xl border border-base-300 bg-base-100 px-4 py-3 focus:border-orange-400 focus:outline-none"
              />

              <div class="fieldset mb-2">
                <label>
                  <span class="label mb-1">Conteudo do template</span>
                  <textarea
                    id="template-content-input"
                    name={@template_form[:content].name}
                    class="hidden"
                  >{Phoenix.HTML.Form.normalize_value("textarea", @template_form[:content].value)}</textarea>
                  <div
                    id="template-content-editor"
                    phx-hook="TemplateEditor"
                    phx-update="ignore"
                    data-target-input-id="template-content-input"
                    data-content={@template.content || ""}
                    data-content-revision={@editor_revision}
                    data-variable-names={Jason.encode!(@editor_variable_names)}
                    class="overflow-hidden rounded-[1.5rem]"
                  />
                </label>
              </div>

              <div class="mt-4 space-y-3" id="template-editor-actions">
                <p class="text-xs font-semibold uppercase tracking-[0.18em] text-base-content/45">
                  Atalhos de criacao
                </p>

                <div class="flex flex-wrap gap-3">
                  <button
                    type="button"
                    id="create-texto-button"
                    phx-click="insert_snippet"
                    phx-value-snippet="texto"
                    class="btn btn-primary rounded-2xl"
                  >
                    Criar @texto
                  </button>
                  <button
                    type="button"
                    id="create-data-button"
                    phx-click="insert_snippet"
                    phx-value-snippet="data"
                    class="btn btn-outline rounded-2xl"
                  >
                    Criar @data
                  </button>
                  <button
                    type="button"
                    id="create-numero-button"
                    phx-click="insert_snippet"
                    phx-value-snippet="numero"
                    class="btn btn-outline rounded-2xl"
                  >
                    Criar @numero
                  </button>
                  <button
                    type="button"
                    id="create-booleano-button"
                    phx-click="insert_snippet"
                    phx-value-snippet="booleano"
                    class="btn btn-outline rounded-2xl"
                  >
                    Criar @booleano
                  </button>
                  <button
                    type="button"
                    id="create-lista-button"
                    phx-click="insert_snippet"
                    phx-value-snippet="lista"
                    class="btn btn-outline rounded-2xl"
                  >
                    Criar @lista
                  </button>
                  <button
                    type="button"
                    id="create-ia-button"
                    phx-click="insert_snippet"
                    phx-value-snippet="ia"
                    class="btn btn-outline rounded-2xl"
                  >
                    Criar @ia
                  </button>
                  <button
                    type="button"
                    id="create-if-block-button"
                    phx-click="insert_snippet"
                    phx-value-snippet="bloco_se"
                    class="btn btn-outline rounded-2xl"
                  >
                    Criar Bloco Se
                  </button>
                </div>
              </div>

              <.syntax_manual id="editor-syntax-manual" class="mt-4" />

              <div
                :if={@parse_errors != []}
                id="template-parse-errors"
                class="mt-4 rounded-[1.5rem] border border-amber-300/60 bg-amber-50 px-4 py-4 text-amber-950 dark:border-amber-400/30 dark:bg-amber-400/10 dark:text-amber-100"
              >
                <div class="flex items-start gap-3">
                  <div class="mt-0.5 rounded-xl bg-amber-500/15 p-2 text-amber-600 dark:text-amber-200">
                    <.icon name="hero-exclamation-triangle" class="size-5" />
                  </div>
                  <div class="space-y-2">
                    <h2 class="text-sm font-semibold uppercase tracking-[0.18em]">
                      Erros de parsing
                    </h2>
                    <p class="text-sm leading-6 text-amber-900/80 dark:text-amber-100/80">
                      O preview e o formulario dinamico ficam limitados enquanto o template nao volta a obedecer a sintaxe da V1.
                    </p>
                    <ul class="space-y-2 text-sm leading-6">
                      <li
                        :for={error <- @parse_errors}
                        class="rounded-2xl bg-white/50 px-3 py-2 dark:bg-white/5"
                      >
                        {error}
                      </li>
                    </ul>
                  </div>
                </div>
              </div>

              <div class="mt-6 flex flex-wrap items-center justify-between gap-3 rounded-[1.5rem] border border-base-300/70 bg-base-200/50 px-4 py-4">
                <p class="text-sm leading-6 text-base-content/65">
                  As alteracoes no conteudo recompilam o preview imediatamente. Use salvar quando quiser persistir no banco.
                  <span class="font-medium text-base-content/80">{@save_hint}</span>
                </p>
                <.button
                  type="submit"
                  id="save-template-button"
                  phx-disable-with="Salvando..."
                  class="rounded-2xl bg-orange-400 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-orange-300"
                >
                  Salvar modelo
                </.button>
              </div>
            </.form>
          </div>
        </div>

        <div class="overflow-hidden rounded-[2rem] border border-base-300/70 bg-base-100 shadow-[0_28px_90px_-50px_rgba(15,23,42,0.55)]">
          <div class="border-b border-base-300/70 px-6 py-5">
            <h2 class="text-xl font-semibold">Formulario dinamico</h2>
            <p class="mt-2 text-sm leading-6 text-base-content/65">
              Os campos abaixo refletem apenas as variaveis ativas no estado atual do template.
            </p>
          </div>

          <div class="px-6 py-6">
            <.form
              id="template-answers-form"
              for={to_form(%{}, as: :answers)}
              phx-change="update_answers"
            >
              <div
                :if={@variables == [] and @parse_errors == []}
                id="template-answers-empty-state"
                class="rounded-[1.5rem] border border-dashed border-base-300 bg-base-200/40 px-4 py-8 text-center text-sm leading-6 text-base-content/60"
              >
                Adicione declaracoes como
                <code class="rounded bg-base-300 px-1 py-0.5">!@cliente</code>
                no editor para gerar campos aqui.
              </div>

              <div
                :if={@parse_errors != []}
                id="template-answers-error-state"
                class="rounded-[1.5rem] border border-dashed border-amber-300/60 bg-amber-50 px-4 py-8 text-center text-sm leading-6 text-amber-900 dark:border-amber-400/30 dark:bg-amber-400/10 dark:text-amber-100"
              >
                Corrija os erros de parsing para recalcular os campos dinamicos desta coluna.
              </div>

              <div :if={@variables != []} class="space-y-4">
                <div
                  :if={has_ai_variables?(@variables)}
                  id="ai-global-context-panel"
                  class="rounded-[1.5rem] border border-violet-200/80 bg-violet-50/60 p-4 dark:border-violet-400/20 dark:bg-violet-500/10"
                >
                  <div class="mb-3 flex items-center justify-between gap-3">
                    <div>
                      <h3 class="text-sm font-semibold text-base-content/85">Contexto Global</h3>
                      <p class="mt-1 text-xs leading-5 text-base-content/60">
                        Cole aqui o material bruto que deve orientar todas as geracoes de IA deste template.
                      </p>
                    </div>
                    <span class="rounded-full border border-violet-200/80 bg-white/80 px-2 py-1 text-[11px] font-medium uppercase tracking-[0.16em] text-violet-700 dark:border-violet-300/30 dark:bg-white/5 dark:text-violet-200">
                      IA
                    </span>
                  </div>

                  <.input
                    id="ai-global-context"
                    name="ai[context]"
                    type="textarea"
                    value={@ai_context}
                    rows="8"
                    class="w-full rounded-2xl border border-violet-200/80 bg-white px-4 py-3 leading-6 focus:border-violet-400 focus:outline-none dark:border-violet-300/20 dark:bg-slate-950/40"
                  />
                </div>

                <div
                  :for={variable <- @variables}
                  id={"variable-panel-#{variable.name}"}
                  class="rounded-[1.5rem] border border-base-300/70 bg-base-200/30 p-4"
                >
                  <%= if variable.type == "ia" do %>
                    <div class="space-y-4">
                      <div class="flex items-start justify-between gap-3">
                        <div>
                          <label
                            for={"ai_prompt_#{variable.name}"}
                            class="text-sm font-semibold text-base-content/80"
                          >
                            {humanize_variable_name(variable.name)}
                          </label>
                          <p class="mt-1 text-xs leading-5 text-base-content/60">
                            Ajuste a instrucao, gere o texto e revise livremente o resultado antes da compilacao final.
                          </p>
                        </div>
                        <span class="rounded-full border border-violet-200/80 bg-violet-50 px-2 py-1 text-[11px] font-medium uppercase tracking-[0.16em] text-violet-700 dark:border-violet-300/30 dark:bg-violet-400/10 dark:text-violet-200">
                          IA
                        </span>
                      </div>

                      <.input
                        id={"ai_prompt_#{variable.name}"}
                        name={"ai[prompts][#{variable.name}]"}
                        type="textarea"
                        label="Instrucao para IA"
                        value={ai_prompt_value(variable, @ai_prompts)}
                        rows="4"
                        class="w-full rounded-2xl border border-base-300 bg-base-100 px-4 py-3 leading-6 focus:border-violet-400 focus:outline-none"
                      />

                      <div class="flex flex-wrap items-center gap-3">
                        <button
                          type="button"
                          id={"generate-ai-#{variable.name}"}
                          phx-click="generate_ai"
                          phx-value-name={variable.name}
                          disabled={ai_loading?(@ai_loading, variable.name)}
                          class={[
                            "btn rounded-2xl border-0 bg-violet-500 px-4 text-white transition hover:bg-violet-400",
                            ai_loading?(@ai_loading, variable.name) && "cursor-wait opacity-70"
                          ]}
                        >
                          {if(ai_loading?(@ai_loading, variable.name),
                            do: "Gerando...",
                            else: "Gerar com IA"
                          )}
                        </button>

                        <p class="text-xs leading-5 text-base-content/55">
                          O resultado abaixo permanece totalmente editavel e sera usado no lugar de <code class="rounded bg-base-300 px-1 py-0.5">@{variable.name}</code>.
                        </p>
                      </div>

                      <p
                        :if={ai_error_for(@ai_errors, variable.name)}
                        id={"ai-error-#{variable.name}"}
                        class="rounded-2xl border border-rose-200/80 bg-rose-50 px-3 py-3 text-sm leading-6 text-rose-900 dark:border-rose-300/25 dark:bg-rose-500/10 dark:text-rose-100"
                      >
                        {ai_error_for(@ai_errors, variable.name)}
                      </p>

                      <.input
                        id={"answer_#{variable.name}"}
                        name={"answers[#{variable.name}]"}
                        type="textarea"
                        label="Resultado revisavel"
                        value={input_value_for(variable, @answers)}
                        rows="8"
                        class="w-full rounded-2xl border border-base-300 bg-base-100 px-4 py-3 leading-6 focus:border-orange-400 focus:outline-none"
                      />
                    </div>
                  <% else %>
                    <div class="mb-3 flex items-center justify-between gap-3">
                      <label
                        for={"answer_#{variable.name}"}
                        class="text-sm font-semibold text-base-content/80"
                      >
                        {humanize_variable_name(variable.name)}
                      </label>
                      <span class="rounded-full border border-base-300 bg-base-100 px-2 py-1 text-[11px] font-medium uppercase tracking-[0.16em] text-base-content/45">
                        {variable.type}
                      </span>
                    </div>

                    <.input
                      id={"answer_#{variable.name}"}
                      name={"answers[#{variable.name}]"}
                      type={input_type_for(variable)}
                      value={input_value_for(variable, @answers)}
                      checked={input_checked_for(variable, @answers)}
                      options={input_options_for(variable)}
                      prompt={input_prompt_for(variable)}
                      rows="4"
                      class={answer_input_class(variable)}
                    />
                  <% end %>
                </div>
              </div>
            </.form>
          </div>
        </div>

        <div class="overflow-hidden rounded-[2rem] border border-base-300/70 bg-slate-950 text-slate-50 shadow-[0_32px_90px_-45px_rgba(15,23,42,0.95)] dark:border-slate-700 dark:bg-slate-900">
          <div class="border-b border-white/10 px-6 py-5">
            <h2 class="text-xl font-semibold">Preview compilado</h2>
            <p class="mt-2 text-sm leading-6 text-slate-300/75">
              {preview_help(@parse_errors)}
            </p>
          </div>

          <div class="px-6 py-6">
            <div
              :if={@parse_errors != []}
              id="template-preview-error-state"
              class="mb-4 rounded-[1.5rem] border border-amber-300/25 bg-amber-400/10 px-4 py-4 text-sm leading-6 text-amber-100"
            >
              O preview abaixo mostra o estado interrompido da compilacao enquanto houver erro de parsing.
            </div>
            <pre
              id="final-document-preview"
              class="min-h-[36rem] overflow-x-auto rounded-[1.5rem] border border-white/10 bg-white/5 px-4 py-4 text-sm leading-7 text-slate-100 whitespace-pre-wrap"
            >{@final_document}</pre>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("update_template", %{"template" => attrs}, socket) do
    template = merge_template(socket.assigns.template, attrs)

    {:noreply,
     assign_editor_state(socket, template, socket.assigns.answers,
       save_state: :dirty,
       reset_ai_prompts: true
     )}
  end

  @impl true
  def handle_event("editor_changed", %{"content" => content} = params, socket) do
    template = %{socket.assigns.template | content: content}
    revision = parse_editor_revision(params["revision"], socket.assigns.editor_revision)

    {:noreply,
     assign_editor_state(socket, template, socket.assigns.answers,
       save_state: :dirty,
       editor_revision: revision,
       reset_ai_prompts: true
     )}
  end

  @impl true
  def handle_event("update_answers", params, socket) do
    raw_answers = Map.get(params, "answers", %{})
    answers = normalize_answers(raw_answers, socket.assigns.variables, socket.assigns.answers)
    ai_params = Map.get(params, "ai", %{})
    ai_context = normalize_ai_context(ai_params, socket.assigns.ai_context)

    ai_prompts =
      normalize_ai_prompts(ai_params, socket.assigns.variables, socket.assigns.ai_prompts)

    {:noreply,
     assign_editor_state(socket, socket.assigns.template, answers,
       save_state: socket.assigns.save_state,
       ai_context: ai_context,
       ai_prompts: ai_prompts,
       ai_errors: clear_ai_errors(socket.assigns.ai_errors, ai_prompts)
     )}
  end

  @impl true
  def handle_event("generate_ai", %{"name" => name}, socket) do
    if ai_loading?(socket.assigns.ai_loading, name) do
      {:noreply, socket}
    else
      prompt = Map.get(socket.assigns.ai_prompts, name, "")
      context = socket.assigns.ai_context

      {:noreply,
       socket
       |> assign(:ai_loading, Map.put(socket.assigns.ai_loading, name, true))
       |> assign(:ai_errors, Map.delete(socket.assigns.ai_errors, name))
       |> start_async({:generate_ai, name}, fn ->
         Documents.generate_ai_text(%{variable_name: name, prompt: prompt, context: context})
       end)}
    end
  end

  @impl true
  def handle_event("insert_snippet", %{"snippet" => snippet_name}, socket) do
    updated_template =
      socket.assigns.template
      |> Map.update!(:content, &append_snippet(&1, snippet_for(snippet_name)))

    {:noreply,
     assign_editor_state(socket, updated_template, socket.assigns.answers,
       save_state: :dirty,
       editor_revision: next_editor_revision(socket),
       reset_ai_prompts: true
     )}
  end

  @impl true
  def handle_event("save", %{"template" => attrs}, socket) do
    case Documents.update_template(socket.assigns.current_scope, socket.assigns.template, attrs) do
      {:ok, template} ->
        save_state =
          case Documents.analyze_template(template, socket.assigns.answers) do
            {:ok, _analysis} -> :saved
            {:error, _errors} -> :saved_with_warnings
          end

        {:noreply,
         socket
         |> put_flash(:info, save_flash_message(save_state))
         |> assign_editor_state(template, socket.assigns.answers,
           save_state: save_state,
           reset_ai_prompts: true
         )}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Nao foi possivel salvar o modelo.")
         |> assign_editor_state(
           merge_template(socket.assigns.template, attrs),
           socket.assigns.answers,
           save_state: :save_error,
           reset_ai_prompts: true
         )}
    end
  end

  @impl true
  def handle_async({:generate_ai, name}, {:ok, {:ok, generated_text}}, socket) do
    answers = Map.put(socket.assigns.answers, name, generated_text)

    {:noreply,
     assign_editor_state(socket, socket.assigns.template, answers,
       save_state: socket.assigns.save_state,
       ai_context: socket.assigns.ai_context,
       ai_prompts: socket.assigns.ai_prompts,
       ai_loading: Map.put(socket.assigns.ai_loading, name, false),
       ai_errors: Map.delete(socket.assigns.ai_errors, name)
     )}
  end

  @impl true
  def handle_async({:generate_ai, name}, {:ok, {:error, error}}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, error)
     |> assign(:ai_loading, Map.put(socket.assigns.ai_loading, name, false))
     |> assign(:ai_errors, Map.put(socket.assigns.ai_errors, name, error))}
  end

  @impl true
  def handle_async({:generate_ai, name}, {:exit, reason}, socket) do
    error = "Nao foi possivel concluir a geracao com IA: #{inspect(reason)}"

    {:noreply,
     socket
     |> put_flash(:error, error)
     |> assign(:ai_loading, Map.put(socket.assigns.ai_loading, name, false))
     |> assign(:ai_errors, Map.put(socket.assigns.ai_errors, name, error))}
  end

  defp assign_editor_state(socket, template, answers, opts) do
    save_state = Keyword.get(opts, :save_state, :saved)
    editor_revision = Keyword.get(opts, :editor_revision, socket.assigns[:editor_revision] || 0)
    ai_context = Keyword.get(opts, :ai_context, socket.assigns[:ai_context] || "")
    ai_loading = Keyword.get(opts, :ai_loading, socket.assigns[:ai_loading] || %{})
    ai_errors = Keyword.get(opts, :ai_errors, socket.assigns[:ai_errors] || %{})
    ai_prompts = Keyword.get(opts, :ai_prompts, socket.assigns[:ai_prompts] || %{})
    reset_ai_prompts = Keyword.get(opts, :reset_ai_prompts, false)

    case Documents.analyze_template(template, answers) do
      {:ok, analysis} ->
        ai_prompts =
          sync_ai_prompts(analysis.parsed_template.variables, ai_prompts, reset_ai_prompts)

        socket
        |> assign(:page_title, "Editor")
        |> assign(:template, template)
        |> assign(:editor_revision, editor_revision)
        |> assign(:template_variables, analysis.parsed_template.variables)
        |> assign(:variables, analysis.variables)
        |> assign(:answers, answers)
        |> assign(:ai_context, ai_context)
        |> assign(:ai_prompts, ai_prompts)
        |> assign(:ai_loading, ai_loading)
        |> assign(:ai_errors, ai_errors)
        |> assign(:final_document, analysis.final_document)
        |> assign(:parse_errors, [])
        |> assign(:save_state, save_state)
        |> assign(:save_hint, save_hint(save_state, []))

      {:error, errors} ->
        socket
        |> assign(:page_title, "Editor")
        |> assign(:template, template)
        |> assign(:editor_revision, editor_revision)
        |> assign(:template_variables, [])
        |> assign(:variables, [])
        |> assign(:answers, answers)
        |> assign(:ai_context, ai_context)
        |> assign(:ai_prompts, ai_prompts)
        |> assign(:ai_loading, ai_loading)
        |> assign(:ai_errors, ai_errors)
        |> assign(:final_document, "Erro no template:\n" <> Enum.join(errors, "\n"))
        |> assign(:parse_errors, errors)
        |> assign(:save_state, save_state)
        |> assign(:save_hint, save_hint(save_state, errors))
    end
  end

  defp save_state_label(:saved), do: "Salvo"
  defp save_state_label(:saved_with_warnings), do: "Salvo com alertas"
  defp save_state_label(:dirty), do: "Alteracoes locais"
  defp save_state_label(:save_error), do: "Falha ao salvar"

  defp save_state_help(:saved), do: "Tudo que esta na tela ja foi persistido no banco."

  defp save_state_help(:saved_with_warnings),
    do: "O rascunho foi salvo, mas ainda ha problemas na sintaxe do template."

  defp save_state_help(:dirty), do: "Voce editou o modelo e ainda nao persistiu essas mudancas."
  defp save_state_help(:save_error), do: "Tente salvar novamente depois de revisar o conteudo."

  defp save_state_container_class(:saved),
    do: "border-emerald-200/70 bg-emerald-50/80 shadow-emerald-100/70"

  defp save_state_container_class(:saved_with_warnings),
    do: "border-amber-200/70 bg-amber-50/80 shadow-amber-100/70"

  defp save_state_container_class(:dirty),
    do: "border-orange-200/70 bg-orange-50/80 shadow-orange-100/70"

  defp save_state_container_class(:save_error),
    do: "border-rose-200/70 bg-rose-50/80 shadow-rose-100/70"

  defp save_hint(:saved, []), do: " Nenhuma pendencia aberta."

  defp save_hint(:saved, _errors),
    do: " O modelo foi salvo, mas ainda restam alertas para revisar."

  defp save_hint(:saved_with_warnings, _errors),
    do: " O rascunho foi salvo, mas a sintaxe ainda precisa de ajuste."

  defp save_hint(:dirty, []), do: " Ha alteracoes locais aguardando persistencia."
  defp save_hint(:dirty, _errors), do: " Ha alteracoes locais e erros de parsing a revisar."
  defp save_hint(:save_error, _errors), do: " O ultimo salvamento falhou."

  defp save_flash_message(:saved), do: "Modelo salvo com sucesso."

  defp save_flash_message(:saved_with_warnings),
    do: "Modelo salvo, mas ainda ha erros de parsing no template."

  defp preview_help([]),
    do:
      "O documento final responde ao template e as respostas atuais sem precisar sair desta tela."

  defp preview_help(_errors),
    do: "Corrija a sintaxe do template para restaurar o preview compilado completo."

  defp merge_template(template, attrs) do
    %{
      title: Map.get(attrs, "title", template.title),
      description: Map.get(attrs, "description", template.description),
      content: Map.get(attrs, "content", template.content)
    }
    |> then(&struct(template, &1))
  end

  defp append_snippet(content, snippet) do
    content = String.trim_trailing(content || "")

    if content == "" do
      snippet
    else
      content <> "\n\n" <> snippet
    end
  end

  defp snippet_for("texto"), do: "!@texto"
  defp snippet_for("data"), do: "!@data[data]"
  defp snippet_for("numero"), do: "!@numero[numero]"
  defp snippet_for("booleano"), do: "!@booleano?"
  defp snippet_for("lista"), do: "!@lista[lista:opcao_1;opcao_2;opcao_3]"
  defp snippet_for("ia"), do: "!@ia[ia:descreva o que deve ser gerado]"

  defp snippet_for("bloco_se") do
    """
    [SE @var = verdadeiro]
    resultado verdadeiro
    [SENAO]
    resultado falso
    [FIM_SE]
    """
    |> String.trim()
  end

  defp normalize_answers(raw_answers, variables, existing_answers) do
    Enum.reduce(variables, existing_answers, fn variable, answers ->
      raw_value = Map.get(raw_answers, variable.name)
      Map.put(answers, variable.name, normalize_answer_value(variable, raw_value))
    end)
  end

  defp normalize_answer_value(%{type: "booleano"}, value),
    do: value in [true, "true", "1", "on", "sim"]

  defp normalize_answer_value(_variable, nil), do: ""
  defp normalize_answer_value(_variable, value), do: value

  defp normalize_ai_context(ai_params, existing_context) do
    Map.get(ai_params, "context", existing_context)
  end

  defp normalize_ai_prompts(ai_params, variables, existing_prompts) do
    raw_prompts = Map.get(ai_params, "prompts", %{})

    Enum.reduce(variables, existing_prompts, fn
      %{type: "ia", name: name} = variable, prompts ->
        Map.put(
          prompts,
          name,
          Map.get(raw_prompts, name, ai_prompt_value(variable, existing_prompts))
        )

      _variable, prompts ->
        prompts
    end)
  end

  defp sync_ai_prompts(template_variables, existing_prompts, reset?) do
    ai_variables = Enum.filter(template_variables, &(&1.type == "ia"))

    base_prompts =
      if reset? do
        %{}
      else
        Map.take(existing_prompts, Enum.map(ai_variables, & &1.name))
      end

    Enum.reduce(ai_variables, base_prompts, fn variable, prompts ->
      prompt = Map.get(variable, :prompt, "")

      Map.put_new(prompts, variable.name, prompt)
      |> then(fn updated_prompts ->
        if reset?, do: Map.put(updated_prompts, variable.name, prompt), else: updated_prompts
      end)
    end)
  end

  defp clear_ai_errors(existing_errors, ai_prompts) do
    Map.take(existing_errors, Map.keys(ai_prompts))
  end

  defp has_ai_variables?(variables) do
    Enum.any?(variables, &(&1.type == "ia"))
  end

  defp ai_prompt_value(variable, ai_prompts) do
    Map.get(ai_prompts, variable.name, Map.get(variable, :prompt, ""))
  end

  defp ai_loading?(ai_loading, name) do
    Map.get(ai_loading, name, false) == true
  end

  defp ai_error_for(ai_errors, name) do
    Map.get(ai_errors, name)
  end

  defp parse_editor_revision(value, _fallback) when is_integer(value), do: value

  defp parse_editor_revision(value, fallback) when is_binary(value) do
    case Integer.parse(value) do
      {revision, ""} -> revision
      _ -> fallback
    end
  end

  defp parse_editor_revision(_value, fallback), do: fallback

  defp next_editor_revision(socket), do: socket.assigns.editor_revision + 1

  defp template_form(template) do
    %{
      "title" => template.title || "",
      "description" => template.description || "",
      "content" => template.content || ""
    }
    |> to_form(as: :template)
  end

  defp editor_variable_names(variables) do
    variables
    |> Enum.map(& &1.name)
    |> Enum.sort()
  end

  defp humanize_variable_name(name) do
    name
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp input_type_for(%{type: "data"}), do: "date"
  defp input_type_for(%{type: "numero"}), do: "number"
  defp input_type_for(%{type: "booleano"}), do: "checkbox"
  defp input_type_for(%{type: "lista"}), do: "select"
  defp input_type_for(%{type: "ia"}), do: "textarea"
  defp input_type_for(_variable), do: "text"

  defp input_value_for(%{type: "booleano"}, _answers), do: nil
  defp input_value_for(variable, answers), do: Map.get(answers, variable.name, "")

  defp input_checked_for(%{type: "booleano", name: name}, answers),
    do: Map.get(answers, name, false) == true

  defp input_checked_for(_variable, _answers), do: false

  defp input_options_for(%{type: "lista", options: options}), do: options
  defp input_options_for(_variable), do: []

  defp input_prompt_for(%{type: "lista"}), do: "Selecione"
  defp input_prompt_for(_variable), do: nil

  defp answer_input_class(%{type: "checkbox"}), do: nil

  defp answer_input_class(%{type: "booleano"}) do
    "checkbox checkbox-sm border-base-300 bg-base-100 text-orange-500"
  end

  defp answer_input_class(%{type: "ia"}) do
    "w-full rounded-2xl border border-base-300 bg-base-100 px-4 py-3 leading-6 focus:border-orange-400 focus:outline-none"
  end

  defp answer_input_class(_variable) do
    "w-full rounded-2xl border border-base-300 bg-base-100 px-4 py-3 focus:border-orange-400 focus:outline-none"
  end
end
