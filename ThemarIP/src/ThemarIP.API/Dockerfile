FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /app

COPY src/ThemarIP.Domain/*.csproj src/ThemarIP.Domain/
COPY src/ThemarIP.Application/*.csproj src/ThemarIP.Application/
COPY src/ThemarIP.Infrastructure/*.csproj src/ThemarIP.Infrastructure/
COPY src/ThemarIP.API/*.csproj src/ThemarIP.API/
RUN dotnet restore src/ThemarIP.API/ThemarIP.API.csproj

COPY src/ src/
RUN dotnet publish src/ThemarIP.API/ThemarIP.API.csproj -c Release -o /out

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /out .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "ThemarIP.API.dll"]
