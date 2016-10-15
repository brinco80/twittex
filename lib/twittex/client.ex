defmodule Twittex.Client do
  @moduledoc """
  Twitter client implementation, provides helper functions to query the API.
  """
  use Twittex.Client.Base

  alias Experimental.GenStage

  @doc """
  Returns a collection of relevant Tweets matching the given `query`.
  """
  @spec search(String.t, Keyword.t) :: {:ok, %{}} | {:error, HTTPoison.Error.t}
  def search(query, options \\ []) do
    get "/search/tweets.json?" <> URI.encode_query(Dict.merge(%{q: query}, options))
  end

  @doc """
  Same as `search/2` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec search!(String.t, Keyword.t) :: %{}
  def search!(query, options \\ []) do
    get! "/search/tweets.json?" <> URI.encode_query(Dict.merge(%{q: query}, options))
  end

  @doc """
  Returns the 20 most recent mentions (tweets containing a users’s `@screen_name`)
  for the authenticating user.
  """
  @spec mentions_timeline(Keyword.t) :: {:ok, %{}} | {:error, HTTPoison.Error.t}
  def mentions_timeline(options \\ []) do
    get "/statuses/mentions_timeline.json?" <> URI.encode_query(options)
  end

  @doc """
  Same as `mentions_timeline/1` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec mentions_timeline!(Keyword.t) :: %{}
  def mentions_timeline!(options \\ []) do
    get! "/statuses/mentions_timeline.json?" <> URI.encode_query(options)
  end

  @doc """
  Returns a collection of the most recent Tweets posted by the user with the given
  `screen_name`.
  """
  @spec user_timeline(String.t, Keyword.t) :: {:ok, %{}} | {:error, HTTPoison.Error.t}
  def user_timeline(screen_name, options \\ []) do
    get "/statuses/user_timeline.json?" <> URI.encode_query(Dict.merge(%{screen_name: screen_name}, options))
  end

  @doc """
  Same as `user_timeline/2` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec user_timeline!(String.t, Keyword.t) :: %{}
  def user_timeline!(screen_name, options \\ []) do
    get! "/statuses/user_timeline.json?" <> URI.encode_query(Dict.merge(%{screen_name: screen_name}, options))
  end

  @doc """
  Returns a collection of the most recent Tweets and retweets posted by the
  authenticating user and the users they follow.
  """
  @spec home_timeline(Keyword.t) :: {:ok, %{}} | {:error, HTTPoison.Error.t}
  def home_timeline(options \\ []) do
    get "/statuses/home_timeline.json?" <> URI.encode_query(options)
  end

  @doc """
  Same as `home_timeline/1` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec home_timeline!(Keyword.t) :: %{}
  def home_timeline!(options \\ []) do
    get! "/statuses/home_timeline.json?" <> URI.encode_query(options)
  end

  @doc """
  Returns the most recent tweets authored by the authenticating user that have been
  retweeted by others.
  """
  @spec retweets_of_me(Keyword.t) :: {:ok, %{}} | {:error, HTTPoison.Error.t}
  def retweets_of_me(options \\ []) do
    get "/statuses/retweets_of_me.json?" <> URI.encode_query(options)
  end

  @doc """
  Same as `retweets_of_me/1` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec retweets_of_me!(Keyword.t) :: %{}
  def retweets_of_me!(options \\ []) do
    get! "/statuses/retweets_of_me.json?" <> URI.encode_query(options)
  end

  @doc """
  Returns a stream of relevant Tweets matching the given `query`.

  If `query` is set to `:sample`, this function returns a small random sample
  of all public statuses (roughly 1% of all public Tweets).

  ## Options

  * `:min_demand` - the minimum demand for this subscription
  * `:max_demand` - the maximum demand for this subscription
  """
  @spec stream(String.t | :sample, Keyword.t) :: {:ok, Enumerable.t} | {:error, HTTPoison.Error.t}
  def stream(query \\ :sample, options \\ []) do
    {bare_stage, options} = Keyword.pop options, :stage, false
    {min_demand, options} = Keyword.pop options, :min_demand, 500
    {max_demand, options} = Keyword.pop options, :max_demand, 1_000

    url =
      if query == :sample do
        "https://stream.twitter.com/1.1/statuses/sample.json?" <> URI.encode_query(Dict.merge(%{delimited: "length"}, options))
      else
        "https://stream.twitter.com/1.1/statuses/filter.json?" <> URI.encode_query(Dict.merge(%{track: query, delimited: "length"}, options))
      end

    case stage :post, url do
      {:ok, stage} ->
        if bare_stage do
          {:ok, stage}
        else
          {:ok, GenStage.stream([{stage, [min_demand: min_demand, max_demand: max_demand]}])}
        end
      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Same as `stream/2` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec stream!(String.t |:sample, Keyword.t) :: Enumerable.t
  def stream!(query \\ :sample, options \\ []) do
    case stream(query, options) do
      {:ok, stream} ->
        stream
      {:error, error} ->
        raise error
    end
  end

  @doc """
  Returns a stream of tweets authored by the authenticating user.

  ## Options

  * `:min_demand` - the minimum demand for this subscription
  * `:max_demand` - the maximum demand for this subscription
  """
  @spec user_stream(Keyword.t) :: {:ok, Enumerable.t} | {:error, HTTPoison.Error.t}
  def user_stream(options \\ []) do
    {bare_stage, options} = Keyword.pop options, :stage, false
    {min_demand, options} = Keyword.pop options, :min_demand, 500
    {max_demand, options} = Keyword.pop options, :max_demand, 1_000

    case stage :post, "https://userstream.twitter.com/1.1/user.json?" <> URI.encode_query(Dict.merge(%{delimited: "length"}, options)) do
      {:ok, stage} ->
        if bare_stage do
          {:ok, stage}
        else
          {:ok, GenStage.stream([{stage, [min_demand: min_demand, max_demand: max_demand]}])}
        end
      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Same as `user_stream/2` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec user_stream(Keyword.t) :: Enumerable.t
  def user_stream!(options \\ []) do
    case user_stream(options) do
      {:ok, stream} ->
        stream
      {:error, error} ->
        raise error
    end
  end
end
