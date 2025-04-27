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
    plug(:fetch_session)
    plug(:accepts, ["json"])
  end

  # Suggestion: make a pipeline that only allows authenticated users. (You might need to make a plug).
  # Then you can throw ALL of your authenticated routes into that, and you shouldn't need to worry
  # about manually authenticated a user.

  pipeline :authenticated do
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug FluffyWeb.Plugs.Authentication
  end

  pipeline :admin_only do
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_secure_browser_headers)
    plug FluffyWeb.Plugs.Authentication
    plug FluffyWeb.Plugs.AdminOnly
  end


  scope "/", FluffyWeb do
    pipe_through(:browser)

    get("/", PageController, :home, private: %{:javascript => "home"})
    get("/publish", PageController, :home, private: %{:javascript => "publish_data"})
    get("/help", PageController, :home, private: %{:javascript => "help"})
    get("/home", PageController, :home, private: %{:javascript => "home"})
    get("/contact", PageController, :home, private: %{:javascript => "contact"})
    get("/auth/google/callback", GoogleAuthController, :index)
    get("/auth/google/page", PageController, :home, private: %{:javascript => "new"})
    get("/logout", GoogleAuthController, :logout)
    get("/documents/:id", MongoDBController, :show_html)
    get("/image/:id", MongoDBController, :get_image)
    get("/survey", PageController, :home, private: %{:javascript => "surveys"})
  end

  scope "/", FluffyWeb do
    pipe_through([:browser, :authenticated]) # Requires authentication
    get("/uploading", PageController, :home, private: %{:javascript => "uploading_data"})
    post("/uploading", PageController, :upload)
    get("/csvupload", PageController, :home, private: %{:javascript => "csvupload"})
    post("/csvupload", PageController, :upload_csv)
    get("/profile", PageController, :home, private: %{:javascript => "profile"})
    # get("/publish", PageController, :home, private: %{:javascript => "publish_data"})
    get("/uploadpage", PageController, :home, private: %{:javascript => "upload_page"})
  end

  scope "/", FluffyWeb do
    pipe_through(:admin_only)
    post "/api/Mongodb/approve_document/:id", MongoDBController, :approve
  end

  # Other scopes may use custom stacks.
  scope "/api", FluffyWeb do
    pipe_through(:api)

    # Route for searching documents for text
    get("/Mongodb/document/search", MongoDBController, :search)

    # Route for retrieving a document
    get("/Mongodb/documents/:id", MongoDBController, :show)

    # Route for creating a document
    post("/Mongodb/documents/newdoc", MongoDBController, :create)

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

    # Add a route for viewing the calender
    get("/calender", MongoDBController, :to_calender)

    # Handle document approvals by setting the approved field to true
    # post "/Mongodb/approve_document/:id", MongoDBController, :approve

    # Get approved documents
    get "/Mongodb/approved_documents", MongoDBController, :approved

    # See unapproved documents
    get "/Mongodb/unapproved_documents", MongoDBController, :unapproved
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
