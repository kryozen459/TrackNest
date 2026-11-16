#include "flutter_window.h"

#include <filesystem>
#include <optional>
#include <string>
#include <thread>
#include <vector>

#include "audio_converter.h"
#include "media_downloader.h"
#include "flutter/generated_plugin_registrant.h"

namespace {

std::string Utf8FromWide(const std::wstring& value) {
  if (value.empty()) {
    return {};
  }
  const int required = WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1,
                                           nullptr, 0, nullptr, nullptr);
  if (required <= 1) {
    return {};
  }
  std::string converted(static_cast<size_t>(required), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, converted.data(), required,
                      nullptr, nullptr);
  converted.pop_back();
  return converted;
}

bool WideFromUtf8(const std::string& value, std::wstring* converted) {
  if (converted == nullptr || value.empty()) {
    return false;
  }
  const int required = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                            value.c_str(), -1, nullptr, 0);
  if (required <= 1) {
    return false;
  }
  std::wstring wide(static_cast<size_t>(required), L'\0');
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.c_str(), -1,
                           wide.data(), required) == 0) {
    return false;
  }
  wide.pop_back();
  *converted = std::move(wide);
  return true;
}
const flutter::EncodableValue* FindMapValue(
    const flutter::EncodableMap* map, const std::string& key) {
  if (map == nullptr) {
    return nullptr;
  }
  const auto item = map->find(flutter::EncodableValue(key));
  return item == map->end() ? nullptr : &item->second;
}

constexpr UINT kAudioConversionCompleteMessage = WM_APP + 23;

struct AudioConversionReply {
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
  flutter::EncodableValue value;
};

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  audio_converter_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "tracknest/audio_converter",
          &flutter::StandardMethodCodec::GetInstance());
  audio_converter_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<
                 flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "selectAudioFiles") {
          std::vector<std::wstring> paths;
          const HRESULT hr = SelectAudioFiles(GetHandle(), &paths);
          if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
            result->Success(flutter::EncodableValue());
            return;
          }
          if (FAILED(hr)) {
            result->Error("file_picker_failed",
                          "Windows could not open the audio file picker.");
            return;
          }
          flutter::EncodableList encoded_paths;
          encoded_paths.reserve(paths.size());
          for (const auto& path : paths) {
            encoded_paths.emplace_back(Utf8FromWide(path));
          }
          result->Success(flutter::EncodableValue(std::move(encoded_paths)));
          return;
        }

        if (call.method_name() == "selectMusicFiles") {
          std::vector<std::wstring> paths;
          const HRESULT hr = SelectMusicFiles(GetHandle(), &paths);
          if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
            result->Success(flutter::EncodableValue());
            return;
          }
          if (FAILED(hr)) {
            result->Error("file_picker_failed",
                          "Windows could not open the music file picker.");
            return;
          }
          flutter::EncodableList encoded_paths;
          encoded_paths.reserve(paths.size());
          for (const auto& path : paths) {
            encoded_paths.emplace_back(Utf8FromWide(path));
          }
          result->Success(flutter::EncodableValue(std::move(encoded_paths)));
          return;
        }

        if (call.method_name() == "selectOutputFolder") {
          std::wstring path;
          const HRESULT hr = SelectOutputFolder(GetHandle(), &path);
          if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
            result->Success(flutter::EncodableValue());
            return;
          }
          if (FAILED(hr)) {
            result->Error("folder_picker_failed",
                          "Windows could not open the folder picker.");
            return;
          }
          result->Success(flutter::EncodableValue(Utf8FromWide(path)));
          return;
        }

        if (call.method_name() == "selectOutputMediaFile") {
          const auto* format_value =
              std::get_if<std::string>(call.arguments());
          std::wstring format;
          if (format_value == nullptr || !WideFromUtf8(*format_value, &format)) {
            result->Error("invalid_format", "Choose MP3 or MP4 as the output format.");
            return;
          }
          std::wstring path;
          const HRESULT hr = SelectOutputMediaFile(GetHandle(), format, &path);
          if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
            result->Success(flutter::EncodableValue());
            return;
          }
          if (FAILED(hr)) {
            result->Error("save_picker_failed",
                          "Windows could not open the output file picker.");
            return;
          }
          result->Success(flutter::EncodableValue(Utf8FromWide(path)));
          return;
        }

        if (call.method_name() == "downloadMediaLink") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          const auto* url_value = FindMapValue(arguments, "url");
          const auto* format_value = FindMapValue(arguments, "format");
          const auto* bitrate_value = FindMapValue(arguments, "bitrateKbps");
          const auto* quality_value = FindMapValue(arguments, "maxVideoHeight");
          const auto* compress_value = FindMapValue(arguments, "compressVideo");
          const auto* url = url_value == nullptr
                                ? nullptr
                                : std::get_if<std::string>(url_value);
          const auto* format = format_value == nullptr
                                   ? nullptr
                                   : std::get_if<std::string>(format_value);
          const auto* bitrate = bitrate_value == nullptr
                                    ? nullptr
                                    : std::get_if<int32_t>(bitrate_value);
          const auto* max_video_height = quality_value == nullptr
                                             ? nullptr
                                             : std::get_if<int32_t>(quality_value);
          const auto* compress_video = compress_value == nullptr
                                           ? nullptr
                                           : std::get_if<bool>(compress_value);
          std::wstring wide_url;
          std::wstring wide_format;
          if (url == nullptr || url->empty() || url->size() > 8192 ||
              format == nullptr || bitrate == nullptr ||
              max_video_height == nullptr || compress_video == nullptr ||
              !WideFromUtf8(*url, &wide_url) ||
              !WideFromUtf8(*format, &wide_format) ||
              (wide_format != L"mp3" && wide_format != L"mp4")) {
            result->Error("invalid_arguments",
                          "Enter an HTTPS media or playlist link and choose MP3 or MP4.");
            return;
          }

          std::wstring output_directory;
          const HRESULT picker_hr =
              SelectOutputFolder(GetHandle(), &output_directory);
          if (picker_hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
            result->Success(flutter::EncodableValue());
            return;
          }
          if (FAILED(picker_hr)) {
            result->Error("folder_picker_failed",
                          "Windows could not choose a save folder.");
            return;
          }

          const int selected_bitrate = *bitrate;
          const int selected_video_height = *max_video_height;
          const bool selected_compress_video = *compress_video;
          const HWND window_handle = GetHandle();
          std::thread(
              [wide_url = std::move(wide_url),
               wide_format = std::move(wide_format),
               output_directory = std::move(output_directory),
               selected_bitrate, selected_video_height,
               selected_compress_video, window_handle,
               result = std::move(result)]() mutable {
                std::wstring message;
                const bool success = DownloadAndConvertMediaUrl(
                    wide_url, output_directory, wide_format, selected_bitrate,
                    selected_video_height, selected_compress_video, &message);
                flutter::EncodableMap response;
                response[flutter::EncodableValue("success")] =
                    flutter::EncodableValue(success);
                response[flutter::EncodableValue("outputPath")] =
                    flutter::EncodableValue(success
                                                ? Utf8FromWide(output_directory)
                                                : std::string());
                response[flutter::EncodableValue("message")] =
                    flutter::EncodableValue(success
                                                ? Utf8FromWide(message)
                                                : std::string());
                response[flutter::EncodableValue("error")] =
                    flutter::EncodableValue(success
                                                ? std::string()
                                                : Utf8FromWide(message));
                auto* reply = new AudioConversionReply{
                    std::move(result),
                    flutter::EncodableValue(std::move(response))};
                if (!PostMessage(window_handle,
                                 kAudioConversionCompleteMessage, 0,
                                 reinterpret_cast<LPARAM>(reply))) {
                  delete reply;
                }
              })
              .detach();
          return;
        }        if (call.method_name() == "convertToMp3") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          const auto* input_value = FindMapValue(arguments, "inputPaths");
          const auto* directory_value =
              FindMapValue(arguments, "outputDirectory");
          const auto* bitrate_value = FindMapValue(arguments, "bitrateKbps");
          const auto* input_list =
              input_value == nullptr
                  ? nullptr
                  : std::get_if<flutter::EncodableList>(input_value);
          const auto* directory =
              directory_value == nullptr
                  ? nullptr
                  : std::get_if<std::string>(directory_value);
          const auto* bitrate =
              bitrate_value == nullptr
                  ? nullptr
                  : std::get_if<int32_t>(bitrate_value);
          if (input_list == nullptr || input_list->empty() ||
              directory == nullptr || bitrate == nullptr) {
            result->Error("invalid_arguments",
                          "Select audio files, an output folder, and a bitrate.");
            return;
          }

          std::vector<std::wstring> input_paths;
          input_paths.reserve(input_list->size());
          for (const auto& value : *input_list) {
            const auto* path = std::get_if<std::string>(&value);
            if (path == nullptr || path->empty()) {
              result->Error("invalid_arguments",
                            "The selected audio file path is invalid.");
              return;
            }
            const int required = MultiByteToWideChar(
                CP_UTF8, MB_ERR_INVALID_CHARS, path->c_str(), -1, nullptr, 0);
            if (required <= 1) {
              result->Error("invalid_arguments",
                            "The selected audio file path is invalid.");
              return;
            }
            std::wstring wide_path(static_cast<size_t>(required), L'\0');
            MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path->c_str(),
                                -1, wide_path.data(), required);
            wide_path.pop_back();
            input_paths.push_back(std::move(wide_path));
          }

          const int directory_length = MultiByteToWideChar(
              CP_UTF8, MB_ERR_INVALID_CHARS, directory->c_str(), -1, nullptr, 0);
          if (directory_length <= 1) {
            result->Error("invalid_arguments",
                          "The output folder path is invalid.");
            return;
          }
          std::wstring output_directory(
              static_cast<size_t>(directory_length), L'\0');
          MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, directory->c_str(),
                              -1, output_directory.data(), directory_length);
          output_directory.pop_back();
          std::error_code directory_error;
          if (!std::filesystem::is_directory(
                  std::filesystem::path(output_directory), directory_error)) {
            result->Error("invalid_output_folder",
                          "Choose an existing folder for the converted MP3 files.");
            return;
          }

          const int selected_bitrate = *bitrate;
          const HWND window_handle = GetHandle();
          std::thread(
              [input_paths = std::move(input_paths),
               output_directory = std::move(output_directory),
               selected_bitrate, window_handle,
               result = std::move(result)]() mutable {
                flutter::EncodableList conversions;
                conversions.reserve(input_paths.size());
                for (const auto& input_path : input_paths) {
                  const std::wstring output_path =
                      MakeUniqueMp3Path(output_directory, input_path);
                  std::wstring error_message;
                  const bool success = ConvertAudioToMp3(
                      input_path, output_path, selected_bitrate, &error_message);
                  flutter::EncodableMap item;
                  item[flutter::EncodableValue("inputPath")] =
                      flutter::EncodableValue(Utf8FromWide(input_path));
                  item[flutter::EncodableValue("outputPath")] =
                      flutter::EncodableValue(success
                                                  ? Utf8FromWide(output_path)
                                                  : std::string());
                  item[flutter::EncodableValue("success")] =
                      flutter::EncodableValue(success);
                  item[flutter::EncodableValue("error")] =
                      flutter::EncodableValue(Utf8FromWide(error_message));
                  conversions.emplace_back(std::move(item));
                }
                auto* reply = new AudioConversionReply{
                    std::move(result),
                    flutter::EncodableValue(std::move(conversions))};
                if (!PostMessage(window_handle, kAudioConversionCompleteMessage,
                                 0, reinterpret_cast<LPARAM>(reply))) {
                  delete reply;
                }
              })
              .detach();
          return;
        }

        result->NotImplemented();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });
  flutter_controller_->ForceRedraw();
  return true;
}

void FlutterWindow::OnDestroy() {
  audio_converter_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == kAudioConversionCompleteMessage) {
    std::unique_ptr<AudioConversionReply> reply(
        reinterpret_cast<AudioConversionReply*>(lparam));
    if (reply && reply->result) {
      reply->result->Success(std::move(reply->value));
    }
    return 0;
  }
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}




