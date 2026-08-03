FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY backend/QuyNhaMinh.Api/QuyNhaMinh.Api.csproj backend/QuyNhaMinh.Api/
RUN dotnet restore backend/QuyNhaMinh.Api/QuyNhaMinh.Api.csproj
COPY backend/QuyNhaMinh.Api/ backend/QuyNhaMinh.Api/
RUN dotnet publish backend/QuyNhaMinh.Api/QuyNhaMinh.Api.csproj -c Release -o /app /p:UseAppHost=false
FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app .
ENV ASPNETCORE_URLS=http://+:10000
EXPOSE 10000
ENTRYPOINT ["dotnet", "QuyNhaMinh.Api.dll"]
