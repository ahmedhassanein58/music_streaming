using System.Text;
using Echonova.Api.Models;
using Echonova.Api.Options;
using Echonova.Api.Serialization;
using Echonova.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using MongoDB.Bson.Serialization;

// Allow Song Id and TrackId to deserialize from MongoDB ObjectId (existing Atlas data)
BsonClassMap.RegisterClassMap<Song>(cm =>
{
    cm.AutoMap();
    cm.SetIgnoreExtraElements(true);
    cm.MapIdMember(s => s.Id).SetSerializer(new GuidAcceptingObjectIdSerializer());
    cm.MapMember(s => s.TrackId).SetSerializer(new GuidAcceptingObjectIdSerializer());
});

// Ignore extra elements in embedded docs (e.g. s3_url stored inside audio_feature in some documents)
BsonClassMap.RegisterClassMap<AudioFeature>(cm =>
{
    cm.AutoMap();
    cm.SetIgnoreExtraElements(true);
});

// Allow User, Admin, Playlist, History, AnonymousSession _id (and some Guid fields) from ObjectId
var guidSerializer = new GuidAcceptingObjectIdSerializer();
BsonClassMap.RegisterClassMap<User>(cm =>
{
    cm.AutoMap();
    cm.MapIdMember(u => u.Id).SetSerializer(guidSerializer);
});
BsonClassMap.RegisterClassMap<Admin>(cm =>
{
    cm.AutoMap();
    cm.MapIdMember(a => a.Id).SetSerializer(guidSerializer);
});
BsonClassMap.RegisterClassMap<Playlist>(cm =>
{
    cm.AutoMap();
    cm.MapIdMember(p => p.Id).SetSerializer(guidSerializer);
    cm.MapMember(p => p.UserId).SetSerializer(guidSerializer);
});
BsonClassMap.RegisterClassMap<History>(cm =>
{
    cm.AutoMap();
    cm.MapIdMember(h => h.Id).SetSerializer(guidSerializer);
    cm.MapMember(h => h.UserId).SetSerializer(guidSerializer);
    cm.MapMember(h => h.TrackId).SetSerializer(guidSerializer);
});
BsonClassMap.RegisterClassMap<AnonymousSession>(cm =>
{
    cm.AutoMap();
    cm.MapIdMember(s => s.Id).SetSerializer(guidSerializer);
});

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<MongoDbOptions>(builder.Configuration.GetSection(MongoDbOptions.SectionName));
builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection(JwtOptions.SectionName));
builder.Services.Configure<SmtpOptions>(builder.Configuration.GetSection(SmtpOptions.SectionName));
builder.Services.Configure<AwsOptions>(builder.Configuration.GetSection(AwsOptions.SectionName));
builder.Services.Configure<UploadOptions>(builder.Configuration.GetSection(UploadOptions.SectionName));

builder.Services.AddMongoDb(builder.Configuration);
builder.Services.AddSingleton<IPasswordHasher, PasswordHasher>();
builder.Services.AddSingleton<IJwtService, JwtService>();
builder.Services.AddSingleton<IEmailService, EmailService>();
builder.Services.AddSingleton<IStorageService, S3StorageService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<ISongService, SongService>();
builder.Services.AddScoped<IPlaylistService, PlaylistService>();
builder.Services.AddScoped<IHistoryService, HistoryService>();
builder.Services.AddScoped<IAnonymousSessionService, AnonymousSessionService>();
builder.Services.AddScoped<IAdminService, AdminService>();

var jwtOptions = builder.Configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>() ?? new JwtOptions();
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtOptions.Issuer,
            ValidAudience = jwtOptions.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.Secret))
        };
    });
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("AdminOnly", policy =>
        policy.RequireClaim("isAdmin", "true"));
});

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.SetIsOriginAllowed(origin =>
        {
            if (string.IsNullOrEmpty(origin)) return false;
            var uri = new Uri(origin);
            return (uri.Host == "localhost" || uri.Host == "127.0.0.1" || uri.Host == "10.0.2.2")
                && (uri.Scheme == "http" || uri.Scheme == "https");
        });
        policy.AllowAnyMethod();
        policy.AllowAnyHeader();
        policy.AllowCredentials();
    });
});

builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
    });
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new Microsoft.OpenApi.OpenApiInfo
    {
        Title = "Echonova API",
        Version = "v1"
    });
    options.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.OpenApiSecurityScheme
    {
        In = Microsoft.OpenApi.ParameterLocation.Header,
        Description = "JWT: paste the token from login/signup. Click Authorize and enter: Bearer &lt;your-token&gt;",
        Name = "Authorization",
        Type = Microsoft.OpenApi.SecuritySchemeType.Http,
        Scheme = "Bearer"
    });
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseExceptionHandler(errorApp =>
    {
        errorApp.Run(async context =>
        {
            context.Response.StatusCode = 500;
            context.Response.ContentType = "application/json";
            var ex = context.Features.Get<Microsoft.AspNetCore.Diagnostics.IExceptionHandlerFeature>()?.Error;
            var msg = ex?.Message ?? "Unknown error";
            var detail = ex?.ToString() ?? "";
            await context.Response.WriteAsJsonAsync(new { message = msg, detail });
        });
    });
}

app.UseSwagger();
app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "Echonova API v1"));

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
