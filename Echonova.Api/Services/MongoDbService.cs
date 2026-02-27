using Echonova.Api.Models;
using Echonova.Api.Options;
using Microsoft.Extensions.Options;
using MongoDB.Driver;

namespace Echonova.Api.Services;

public static class MongoDbServiceExtensions
{
    public static IServiceCollection AddMongoDb(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<MongoDbOptions>(configuration.GetSection(MongoDbOptions.SectionName));
        services.AddSingleton<IMongoClient>(sp =>
        {
            var options = sp.GetRequiredService<IOptions<MongoDbOptions>>().Value;
            return new MongoClient(options.ConnectionString);
        });
        services.AddSingleton(sp =>
        {
            var client = sp.GetRequiredService<IMongoClient>();
            var options = sp.GetRequiredService<IOptions<MongoDbOptions>>().Value;
            return client.GetDatabase(options.DatabaseName);
        });
        services.AddSingleton(sp =>
        {
            var db = sp.GetRequiredService<IMongoDatabase>();
            return db.GetCollection<User>("users");
        });
        services.AddSingleton(sp =>
        {
            var db = sp.GetRequiredService<IMongoDatabase>();
            return db.GetCollection<Song>("songs");
        });
        services.AddSingleton(sp =>
        {
            var db = sp.GetRequiredService<IMongoDatabase>();
            return db.GetCollection<Playlist>("playlists");
        });
        services.AddSingleton(sp =>
        {
            var db = sp.GetRequiredService<IMongoDatabase>();
            return db.GetCollection<History>("history");
        });
        services.AddSingleton(sp =>
        {
            var db = sp.GetRequiredService<IMongoDatabase>();
            return db.GetCollection<Admin>("admins");
        });
        return services;
    }
}
