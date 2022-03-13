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

  def origin() do
    GenServer.call(@me, :origin)
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
    results =
      %{}
      |> Map.put(:name, host)
      |> add_host_record(db[host], class, type)

    {:reply, results, db}
  end

  def handle_call(:db, _from, db), do: {:reply, db, db}

  def handle_call(:origin, _from, db), do: {:reply, db.origin, db}

  def add_host_record(result, nil, _class, _type) do
    Map.put(result, :error, :nx_domain)
  end

  def add_host_record(result, host_record, class, type) do
    result
    |> Map.put(:class, class)
    |> add_class_record(host_record[class], type)
  end

  def add_class_record(result, nil, _type) do
    Map.put(result, :error, :nx_class)
  end

  def add_class_record(result, class_record, type) do
    result
    |> Map.put(:type, type)
    |> add_type_record(class_record[type])
  end

  def add_type_record(result, nil) do
    Map.put(result, :error, :nx_type)
  end

  def add_type_record(result, type_record) do
    Map.put(result, :rdata, type_record)
  end
end
