defmodule Fedex.Activitypub.Host do
    defstruct host: nil, hostname: nil

    alias Fedex.Activitypub.Host

    def local(hostname) do
        %Host{hostname: hostname, host: "https://#{hostname}"}
    end
end