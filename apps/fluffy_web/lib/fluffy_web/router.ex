defmodule FluffyWeb.Router do
  use FluffyWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {FluffyWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", FluffyWeb do
    pipe_through(:browser)

    get("/", PageController, :home, private: %{:javascript => "sign_up"})
    get("/publish", PageController, :home, private: %{:javascript => "publish_data"})
    get("/home", PageController, :home, private: %{:javascript => "home"})
    get("/contact", PageController, :home, private: %{:javascript => "contact"})
    get("/sites", PageController, :home, private: %{:javascript => "sites"})
    get("/uploading", PageController, :home, private: %{:javascript => "uploading_data"})
    post("/uploading", PageController, :upload)
    get("/downloading", PageController, :home, private: %{:javascript => "downloading_data"})
    get("/survey", PageController, :home, private: %{:javascript => "surveys"})
    get("/map", PageController, :home, private: %{:javascript => "map"})
    post("/map", PageController, :upload_csv)
  end

  # Other scopes may use custom stacks.
  scope "/api", FluffyWeb do
    pipe_through(:api)

    # Route for searching documents for text
    # get "/documentIdsByText", MongoDBController, :search
    get("/Mongodb/document/search", MongoDBController, :search)

    # Route for retrieving a document
    get("/Mongodb/documents/:id", MongoDBController, :show)

    # Route for creating a document
    post("/Mongodb/documents/newdoc", MongoDBController, :insert_document)

    get("/documents/:db_name", MongoDBController, :fetch_documents)

    # Retrives all the databases that are there
    get("/Mongodb/databases", MongoDBController, :find)

    # Route for updating a document
    put("/Mongodb/documents/:id", MongoDBController, :update)

    # Getting all the docs
    get("/Mongodb/document", MongoDBController, :all)

    # Add a route for uploading CSV files
    post("/Mongodb/upload_csv", MongoDBController, :upload_csv)

    # Add a route for uploading CSV files
    get("/rhodes", MongoDBController, :to_rhodes)
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:fluffy_web, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: FluffyWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
