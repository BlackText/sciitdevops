import http.server
import socketserver
import urllib.parse
import requests

API_KEY = "c7e8201380b541bb997213956250503"
BASE_URL = "http://api.weatherapi.com/v1/current.json"
PORT = 8080

class WeatherHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/weather?"):
            query = urllib.parse.urlparse(self.path).query
            params = urllib.parse.parse_qs(query)
            city = params.get("city", [None])[0]

            if city:
                weather_data = self.fetch_weather(city)
                self.respond_with_weather(weather_data)
            else:
                self.respond_with_message("Please provide a city name.")
        else:
            self.respond_with_form()

    def fetch_weather(self, city):
        params = {"key": API_KEY, "q": city}
        response = requests.get(BASE_URL, params)
        if response.status_code == 200:
            return response.json()
        return {"error": "Could not fetch weather data."}

    def respond_with_weather(self, data):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        self.wfile.write(b"<html><body>")
        if "error" in data:
            self.wfile.write(f"<p>{data['error']}</p>".encode())
        else:
            weather_info = (
                f"<h2>Weather in {data['location']['name']}</h2>"
                f"<p>Temperature: {data['current']['temp_c']} degrees celsius</p>"
                f"<p>Weather: {data['current']['condition']['text']}</p>"
            )
            self.wfile.write(weather_info.encode())
        self.wfile.write(b"<br><a href='/'>Back</a>")
        self.wfile.write(b"</body></html>")

    def respond_with_message(self, message):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        self.wfile.write(f"<html><body><p>{message}</p><br><a href='/'>Back</a></body></html>".encode())

    def respond_with_form(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        self.wfile.write(b"""
            <html>
            <body>
                <h2>Enter a city name to get weather forecast</h2>
                <form action="/weather" method="get">
                    <input type="text" name="city" required>
                    <input type="submit" value="Get Weather">
                </form>
            </body>
            </html>
        """)

with socketserver.TCPServer(("", PORT), WeatherHandler) as httpd:
    print(f"Serving on port {PORT}")
    httpd.serve_forever()

# See PyCharm help at https://www.jetbrains.com/help/pycharm/

