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
    results =
      %{}
      |> Map.put(:name, host)
      |> add_host_record(db[host], class, type, db)

    {:reply, results, db}
  end

  def handle_call(:db, _from, db), do: {:reply, db, db}

  def add_host_record(result, nil, _class, _type, _db) do
    Map.put(result, :error, :nx_domain)
  end

  def add_host_record(result, host_record, class, type, db) do
    result
    |> Map.put(:class, class)
    |> add_class_record(host_record[class], type, db)
  end

  def add_class_record(result, nil, _type, db) do
    add_default_soa(result, db)
  end

  def add_class_record(result, class_record, type, db) do
    add_type_record(result, class_record[type], type, db)
  end

  def add_default_soa(result, db) do
    result
    |> Map.put(:type, :soa)
    |> Map.put(:rdata, db.soa)
  end

  def add_type_record(result, nil, _type, db) do
    add_default_soa(result, db)
  end

  def add_type_record(result, type_record, type, _db) do
    result
    |> Map.put(:type, type)
    |> Map.put(:rdata, type_record)
  end
end
