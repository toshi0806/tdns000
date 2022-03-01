defmodule TDNS00.ZoneDB do
  use GenServer
  @me __MODULE__

  # API
  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @me)
  end

  @spec resolve(String.t(), atom, atom) :: any
  def resolve(host, class, type) do
    GenServer.call(@me, {:resolve, host, class, type})
  end

  def db() do
    GenServer.call(@me, :db)
  end

  # server
  @spec init(String.t()) :: {:ok, any}
  def init(file) do
    {:ok, TDNS00.ZoneParser.parse_file(file)}
  end

  def handle_call({:resolve, host, class, type}, _from, db) do
    results = %{
      host =>
        case Map.get(db, host, nil) do
          nil ->
            %{error: :nx_domain}

          host_record ->
            %{
              class =>
                case Map.get(host_record, class, nil) do
                  nil ->
                    %{soa: db.soa}

                  class_record ->
                    case Map.get(class_record, type, nil) do
                      nil -> %{soa: db.soa}
                      type_record -> %{type => type_record}
                    end
                end
            }
        end
    }

    {:reply, results, db}
  end

  def handle_call(:db, _from, db), do: {:reply, db, db}
end
