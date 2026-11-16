#include "audio_converter.h"

#include <algorithm>
#include <filesystem>
#include <iomanip>
#include <iterator>
#include <sstream>
#include <string>
#include <vector>

#include <mfapi.h>
#include <mferror.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <shobjidl.h>
#include <wrl/client.h>

namespace {

constexpr DWORD kAllStreams = static_cast<DWORD>(MF_SOURCE_READER_ALL_STREAMS);
constexpr DWORD kFirstAudioStream = static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM);
constexpr DWORD kAnyStream = static_cast<DWORD>(MF_SOURCE_READER_ANY_STREAM);

using Microsoft::WRL::ComPtr;

std::wstring HResultMessage(HRESULT hr) {
  wchar_t* system_message = nullptr;
  const DWORD length = FormatMessageW(
      FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
          FORMAT_MESSAGE_IGNORE_INSERTS,
      nullptr, static_cast<DWORD>(hr), MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
      reinterpret_cast<wchar_t*>(&system_message), 0, nullptr);

  std::wstringstream message;
  if (length != 0 && system_message != nullptr) {
    message << system_message;
    LocalFree(system_message);
  } else {
    message << L"Windows Media Foundation error 0x" << std::hex << std::uppercase
            << static_cast<unsigned long>(hr) << L".";
  }
  return message.str();
}

HRESULT GetFileSystemPath(IShellItem* item, std::wstring* path) {
  if (item == nullptr || path == nullptr) {
    return E_POINTER;
  }

  PWSTR file_path = nullptr;
  const HRESULT hr = item->GetDisplayName(SIGDN_FILESYSPATH, &file_path);
  if (SUCCEEDED(hr)) {
    *path = file_path;
  }
  CoTaskMemFree(file_path);
  return hr;
}

bool SetAudioAttribute(IMFMediaType* media_type, REFGUID key, UINT32 value,
                       std::wstring* error_message) {
  const HRESULT hr = media_type->SetUINT32(key, value);
  if (FAILED(hr)) {
    *error_message = HResultMessage(hr);
    return false;
  }
  return true;
}

bool SetAudioGuid(IMFMediaType* media_type, REFGUID key, REFGUID value,
                  std::wstring* error_message) {
  const HRESULT hr = media_type->SetGUID(key, value);
  if (FAILED(hr)) {
    *error_message = HResultMessage(hr);
    return false;
  }
  return true;
}

}  // namespace

HRESULT SelectAudioFiles(HWND owner, std::vector<std::wstring>* paths) {
  if (paths == nullptr) {
    return E_POINTER;
  }
  paths->clear();

  ComPtr<IFileOpenDialog> dialog;
  HRESULT hr = CoCreateInstance(CLSID_FileOpenDialog, nullptr, CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&dialog));
  if (FAILED(hr)) {
    return hr;
  }

  DWORD options = 0;
  hr = dialog->GetOptions(&options);
  if (FAILED(hr)) {
    return hr;
  }
  hr = dialog->SetOptions(options | FOS_ALLOWMULTISELECT | FOS_FORCEFILESYSTEM |
                          FOS_FILEMUSTEXIST | FOS_PATHMUSTEXIST);
  if (FAILED(hr)) {
    return hr;
  }

  const COMDLG_FILTERSPEC filters[] = {
      {L"Audio files", L"*.wav;*.mp3;*.m4a;*.aac;*.wma;*.mp4;*.m4v;*.mov;*.wmv;*.avi"},
      {L"All files", L"*.*"},
  };
  hr = dialog->SetFileTypes(static_cast<UINT>(std::size(filters)), filters);
  if (FAILED(hr)) {
    return hr;
  }

  hr = dialog->Show(owner);
  if (FAILED(hr)) {
    return hr;
  }

  ComPtr<IShellItemArray> selected_items;
  hr = dialog->GetResults(&selected_items);
  if (FAILED(hr)) {
    return hr;
  }

  DWORD count = 0;
  hr = selected_items->GetCount(&count);
  if (FAILED(hr)) {
    return hr;
  }

  for (DWORD index = 0; index < count; ++index) {
    ComPtr<IShellItem> item;
    hr = selected_items->GetItemAt(index, &item);
    if (FAILED(hr)) {
      return hr;
    }
    std::wstring path;
    hr = GetFileSystemPath(item.Get(), &path);
    if (FAILED(hr)) {
      return hr;
    }
    paths->push_back(std::move(path));
  }
  return S_OK;
}

HRESULT SelectMusicFiles(HWND owner, std::vector<std::wstring>* paths) {
  if (paths == nullptr) {
    return E_POINTER;
  }
  paths->clear();

  ComPtr<IFileOpenDialog> dialog;
  HRESULT hr = CoCreateInstance(CLSID_FileOpenDialog, nullptr, CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&dialog));
  if (FAILED(hr)) {
    return hr;
  }

  DWORD options = 0;
  hr = dialog->GetOptions(&options);
  if (FAILED(hr)) {
    return hr;
  }
  hr = dialog->SetOptions(options | FOS_ALLOWMULTISELECT | FOS_FORCEFILESYSTEM |
                          FOS_FILEMUSTEXIST | FOS_PATHMUSTEXIST);
  if (FAILED(hr)) {
    return hr;
  }

  const COMDLG_FILTERSPEC filters[] = {
      {L"Music files", L"*.mp3;*.wav;*.m4a;*.aac;*.wma;*.flac"},
      {L"All files", L"*.*"},
  };
  hr = dialog->SetFileTypes(static_cast<UINT>(std::size(filters)), filters);
  if (FAILED(hr)) {
    return hr;
  }
  hr = dialog->SetTitle(L"Add songs to TrackNest");
  if (FAILED(hr)) {
    return hr;
  }
  hr = dialog->Show(owner);
  if (FAILED(hr)) {
    return hr;
  }

  ComPtr<IShellItemArray> selected_items;
  hr = dialog->GetResults(&selected_items);
  if (FAILED(hr)) {
    return hr;
  }
  DWORD count = 0;
  hr = selected_items->GetCount(&count);
  if (FAILED(hr)) {
    return hr;
  }
  for (DWORD index = 0; index < count; ++index) {
    ComPtr<IShellItem> item;
    hr = selected_items->GetItemAt(index, &item);
    if (FAILED(hr)) {
      return hr;
    }
    std::wstring path;
    hr = GetFileSystemPath(item.Get(), &path);
    if (FAILED(hr)) {
      return hr;
    }
    paths->push_back(std::move(path));
  }
  return S_OK;
}

HRESULT SelectOutputFolder(HWND owner, std::wstring* path) {
  if (path == nullptr) {
    return E_POINTER;
  }
  path->clear();

  ComPtr<IFileOpenDialog> dialog;
  HRESULT hr = CoCreateInstance(CLSID_FileOpenDialog, nullptr, CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&dialog));
  if (FAILED(hr)) {
    return hr;
  }

  DWORD options = 0;
  hr = dialog->GetOptions(&options);
  if (FAILED(hr)) {
    return hr;
  }
  hr = dialog->SetOptions(options | FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM |
                          FOS_PATHMUSTEXIST);
  if (FAILED(hr)) {
    return hr;
  }

  hr = dialog->SetTitle(L"Choose where TrackNest should save the MP3 files");
  if (FAILED(hr)) {
    return hr;
  }
  hr = dialog->Show(owner);
  if (FAILED(hr)) {
    return hr;
  }

  ComPtr<IShellItem> selected_folder;
  hr = dialog->GetResult(&selected_folder);
  if (FAILED(hr)) {
    return hr;
  }
  return GetFileSystemPath(selected_folder.Get(), path);
}

std::wstring MakeUniqueMp3Path(const std::wstring& output_directory,
                               const std::wstring& input_path) {
  namespace fs = std::filesystem;
  const fs::path input(input_path);
  const fs::path directory(output_directory);
  const fs::path first_candidate =
      directory / (input.stem().wstring() + L".mp3");
  std::error_code exists_error;
  if (!fs::exists(first_candidate, exists_error) && !exists_error) {
    return first_candidate.wstring();
  }

  for (unsigned int suffix = 2; suffix < 100000; ++suffix) {
    const fs::path candidate = directory /
        (input.stem().wstring() + L" (" + std::to_wstring(suffix) + L").mp3");
    exists_error.clear();
    if (!fs::exists(candidate, exists_error) && !exists_error) {
      return candidate.wstring();
    }
  }
  return (directory / (input.stem().wstring() + L" - converted.mp3")).wstring();
}

bool ConvertAudioToMp3(const std::wstring& input_path,
                       const std::wstring& output_path, int bitrate_kbps,
                       std::wstring* error_message) {
  if (error_message == nullptr) {
    return false;
  }
  error_message->clear();

  if (bitrate_kbps != 128 && bitrate_kbps != 192 && bitrate_kbps != 256 &&
      bitrate_kbps != 320) {
    *error_message = L"Choose a supported MP3 bitrate.";
    return false;
  }

  const HRESULT com_hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  if (FAILED(com_hr)) {
    *error_message = HResultMessage(com_hr);
    return false;
  }

  HRESULT hr = MFStartup(MF_VERSION, MFSTARTUP_FULL);
  if (FAILED(hr)) {
    *error_message = HResultMessage(hr);
    CoUninitialize();
    return false;
  }

  bool success = false;
  do {
    ComPtr<IMFSourceReader> reader;
    hr = MFCreateSourceReaderFromURL(input_path.c_str(), nullptr, &reader);
    if (FAILED(hr)) {
      *error_message =
          L"Windows could not open this audio file. Try a WAV, MP3, M4A, AAC, "
          L"or WMA file.";
      break;
    }

    hr = reader->SetStreamSelection(kAllStreams, FALSE);
    if (FAILED(hr)) {
      *error_message = HResultMessage(hr);
      break;
    }
    hr = reader->SetStreamSelection(kFirstAudioStream, TRUE);
    if (FAILED(hr)) {
      *error_message = L"No readable audio stream was found in this file.";
      break;
    }

    ComPtr<IMFMediaType> pcm_type;
    hr = MFCreateMediaType(&pcm_type);
    if (FAILED(hr)) {
      *error_message = HResultMessage(hr);
      break;
    }

    const bool pcm_type_ready =
        SetAudioGuid(pcm_type.Get(), MF_MT_MAJOR_TYPE, MFMediaType_Audio,
                     error_message) &&
        SetAudioGuid(pcm_type.Get(), MF_MT_SUBTYPE, MFAudioFormat_PCM,
                     error_message) &&
        SetAudioAttribute(pcm_type.Get(), MF_MT_AUDIO_NUM_CHANNELS, 2,
                          error_message) &&
        SetAudioAttribute(pcm_type.Get(), MF_MT_AUDIO_SAMPLES_PER_SECOND, 44100,
                          error_message) &&
        SetAudioAttribute(pcm_type.Get(), MF_MT_AUDIO_BITS_PER_SAMPLE, 16,
                          error_message) &&
        SetAudioAttribute(pcm_type.Get(), MF_MT_AUDIO_BLOCK_ALIGNMENT, 4,
                          error_message) &&
        SetAudioAttribute(pcm_type.Get(), MF_MT_AUDIO_AVG_BYTES_PER_SECOND,
                          176400, error_message);
    if (!pcm_type_ready) {
      break;
    }

    hr = reader->SetCurrentMediaType(kFirstAudioStream,
                                     nullptr, pcm_type.Get());
    if (FAILED(hr)) {
      *error_message =
          L"Windows could not decode or prepare this audio format. Try a WAV, "
          L"MP3, M4A, AAC, or WMA file.";
      break;
    }

    ComPtr<IMFMediaType> actual_pcm_type;
    hr = reader->GetCurrentMediaType(kFirstAudioStream,
                                     &actual_pcm_type);
    if (FAILED(hr)) {
      *error_message = HResultMessage(hr);
      break;
    }

    ComPtr<IMFSinkWriter> writer;
    hr = MFCreateSinkWriterFromURL(output_path.c_str(), nullptr, nullptr,
                                   &writer);
    if (FAILED(hr)) {
      *error_message =
          L"Windows could not create the MP3 file in the selected folder.";
      break;
    }

    ComPtr<IMFMediaType> mp3_type;
    hr = MFCreateMediaType(&mp3_type);
    if (FAILED(hr)) {
      *error_message = HResultMessage(hr);
      break;
    }

    const bool mp3_type_ready =
        SetAudioGuid(mp3_type.Get(), MF_MT_MAJOR_TYPE, MFMediaType_Audio,
                     error_message) &&
        SetAudioGuid(mp3_type.Get(), MF_MT_SUBTYPE, MFAudioFormat_MP3,
                     error_message) &&
        SetAudioAttribute(mp3_type.Get(), MF_MT_AUDIO_NUM_CHANNELS, 2,
                          error_message) &&
        SetAudioAttribute(mp3_type.Get(), MF_MT_AUDIO_SAMPLES_PER_SECOND, 44100,
                          error_message) &&
        SetAudioAttribute(mp3_type.Get(), MF_MT_AUDIO_AVG_BYTES_PER_SECOND,
                          static_cast<UINT32>(bitrate_kbps * 125),
                          error_message);
    if (!mp3_type_ready) {
      break;
    }

    DWORD output_stream = 0;
    hr = writer->AddStream(mp3_type.Get(), &output_stream);
    if (FAILED(hr)) {
      *error_message =
          L"The Windows MP3 encoder is unavailable on this device.";
      break;
    }
    hr = writer->SetInputMediaType(output_stream, actual_pcm_type.Get(), nullptr);
    if (FAILED(hr)) {
      *error_message =
          L"The Windows MP3 encoder cannot use this audio format.";
      break;
    }
    hr = writer->BeginWriting();
    if (FAILED(hr)) {
      *error_message = HResultMessage(hr);
      break;
    }

    bool read_error = false;
    while (true) {
      DWORD stream_index = 0;
      DWORD stream_flags = 0;
      LONGLONG timestamp = 0;
      ComPtr<IMFSample> sample;
      hr = reader->ReadSample(kFirstAudioStream, 0,
                              &stream_index, &stream_flags, &timestamp, &sample);
      if (FAILED(hr)) {
        *error_message = L"An error occurred while reading the audio file.";
        read_error = true;
        break;
      }
      if ((stream_flags & MF_SOURCE_READERF_ENDOFSTREAM) != 0) {
        break;
      }
      if (sample != nullptr) {
        hr = writer->WriteSample(output_stream, sample.Get());
        if (FAILED(hr)) {
          *error_message = L"An error occurred while encoding the MP3 file.";
          read_error = true;
          break;
        }
      }
    }

    if (read_error) {
      break;
    }
    hr = writer->Finalize();
    if (FAILED(hr)) {
      *error_message = L"Windows could not finish writing the MP3 file.";
      break;
    }
    success = true;
  } while (false);

  MFShutdown();
  CoUninitialize();

  if (!success) {
    std::error_code ignored;
    std::filesystem::remove(std::filesystem::path(output_path), ignored);
  }
  return success;
}



HRESULT SelectOutputMediaFile(HWND owner, const std::wstring& format,
                              std::wstring* path) {
  if (path == nullptr) {
    return E_POINTER;
  }
  if (format != L"mp3" && format != L"mp4") {
    return E_INVALIDARG;
  }
  path->clear();

  ComPtr<IFileSaveDialog> dialog;
  HRESULT hr = CoCreateInstance(CLSID_FileSaveDialog, nullptr,
                                CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&dialog));
  if (FAILED(hr)) {
    return hr;
  }

  DWORD options = 0;
  hr = dialog->GetOptions(&options);
  if (FAILED(hr)) {
    return hr;
  }
  hr = dialog->SetOptions(options | FOS_FORCEFILESYSTEM | FOS_OVERWRITEPROMPT |
                          FOS_PATHMUSTEXIST);
  if (FAILED(hr)) {
    return hr;
  }

  const COMDLG_FILTERSPEC mp3_filter[] = {
      {L"MP3 audio", L"*.mp3"},
  };
  const COMDLG_FILTERSPEC mp4_filter[] = {
      {L"MP4 media", L"*.mp4"},
  };
  if (format == L"mp3") {
    hr = dialog->SetFileTypes(1, mp3_filter);
    if (SUCCEEDED(hr)) {
      hr = dialog->SetDefaultExtension(L"mp3");
    }
    if (SUCCEEDED(hr)) {
      hr = dialog->SetFileName(L"TrackNest-download.mp3");
    }
  } else {
    hr = dialog->SetFileTypes(1, mp4_filter);
    if (SUCCEEDED(hr)) {
      hr = dialog->SetDefaultExtension(L"mp4");
    }
    if (SUCCEEDED(hr)) {
      hr = dialog->SetFileName(L"TrackNest-download.mp4");
    }
  }
  if (FAILED(hr)) {
    return hr;
  }

  hr = dialog->Show(owner);
  if (FAILED(hr)) {
    return hr;
  }
  ComPtr<IShellItem> selected_file;
  hr = dialog->GetResult(&selected_file);
  if (FAILED(hr)) {
    return hr;
  }
  return GetFileSystemPath(selected_file.Get(), path);
}

bool ConvertMediaToMp4(const std::wstring& input_path,
                       const std::wstring& output_path,
                       std::wstring* error_message) {
  if (error_message == nullptr) {
    return false;
  }
  error_message->clear();

  const HRESULT com_hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  if (FAILED(com_hr)) {
    *error_message = HResultMessage(com_hr);
    return false;
  }

  HRESULT hr = MFStartup(MF_VERSION, MFSTARTUP_FULL);
  if (FAILED(hr)) {
    *error_message = HResultMessage(hr);
    CoUninitialize();
    return false;
  }

  constexpr DWORD kNoStream = MAXDWORD;
  DWORD audio_input_stream = kNoStream;
  DWORD video_input_stream = kNoStream;
  bool success = false;

  do {
    ComPtr<IMFSourceReader> reader;
    hr = MFCreateSourceReaderFromURL(input_path.c_str(), nullptr, &reader);
    if (FAILED(hr)) {
      *error_message =
          L"Windows could not open this media file. The source format may not "
          L"be supported by this device.";
      break;
    }

    DWORD stream_index = 0;
    while (stream_index < 64) {
      ComPtr<IMFMediaType> native_type;
      hr = reader->GetNativeMediaType(stream_index, 0, &native_type);
      if (hr == MF_E_INVALIDSTREAMNUMBER) {
        break;
      }
      if (FAILED(hr)) {
        ++stream_index;
        continue;
      }

      GUID major_type = GUID_NULL;
      hr = native_type->GetGUID(MF_MT_MAJOR_TYPE, &major_type);
      if (SUCCEEDED(hr) && IsEqualGUID(major_type, MFMediaType_Audio) &&
          audio_input_stream == kNoStream) {
        audio_input_stream = stream_index;
      } else if (SUCCEEDED(hr) &&
                 IsEqualGUID(major_type, MFMediaType_Video) &&
                 video_input_stream == kNoStream) {
        video_input_stream = stream_index;
      }
      ++stream_index;
    }

    if (audio_input_stream == kNoStream &&
        video_input_stream == kNoStream) {
      *error_message =
          L"The URL did not contain a readable audio or video stream.";
      break;
    }

    hr = reader->SetStreamSelection(kAllStreams, FALSE);
    if (FAILED(hr)) {
      *error_message = HResultMessage(hr);
      break;
    }
    if (video_input_stream != kNoStream) {
      hr = reader->SetStreamSelection(video_input_stream, TRUE);
      if (FAILED(hr)) {
        *error_message = L"Windows could not select the video stream.";
        break;
      }
    }
    if (audio_input_stream != kNoStream) {
      hr = reader->SetStreamSelection(audio_input_stream, TRUE);
      if (FAILED(hr)) {
        *error_message = L"Windows could not select the audio stream.";
        break;
      }
    }

    UINT32 frame_width = 0;
    UINT32 frame_height = 0;
    UINT32 frame_rate_num = 30;
    UINT32 frame_rate_den = 1;
    UINT32 pixel_ratio_num = 1;
    UINT32 pixel_ratio_den = 1;
    ComPtr<IMFMediaType> video_input_type;

    if (video_input_stream != kNoStream) {
      ComPtr<IMFMediaType> native_video_type;
      hr = reader->GetNativeMediaType(video_input_stream, 0,
                                      &native_video_type);
      if (FAILED(hr) ||
          FAILED(MFGetAttributeSize(native_video_type.Get(), MF_MT_FRAME_SIZE,
                                    &frame_width, &frame_height)) ||
          frame_width == 0 || frame_height == 0) {
        *error_message = L"Windows could not read the video's dimensions.";
        break;
      }
      MFGetAttributeRatio(native_video_type.Get(), MF_MT_FRAME_RATE,
                          &frame_rate_num, &frame_rate_den);
      MFGetAttributeRatio(native_video_type.Get(), MF_MT_PIXEL_ASPECT_RATIO,
                          &pixel_ratio_num, &pixel_ratio_den);
      if (frame_rate_num == 0 || frame_rate_den == 0) {
        frame_rate_num = 30;
        frame_rate_den = 1;
      }
      if (pixel_ratio_num == 0 || pixel_ratio_den == 0) {
        pixel_ratio_num = 1;
        pixel_ratio_den = 1;
      }

      ComPtr<IMFMediaType> decoded_video_type;
      hr = MFCreateMediaType(&decoded_video_type);
      if (FAILED(hr)) {
        *error_message = HResultMessage(hr);
        break;
      }
      hr = decoded_video_type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
      if (SUCCEEDED(hr)) {
        hr = decoded_video_type->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_NV12);
      }
      if (SUCCEEDED(hr)) {
        hr = decoded_video_type->SetUINT32(MF_MT_INTERLACE_MODE,
                                           MFVideoInterlace_Progressive);
      }
      if (SUCCEEDED(hr)) {
        hr = MFSetAttributeSize(decoded_video_type.Get(), MF_MT_FRAME_SIZE,
                                frame_width, frame_height);
      }
      if (SUCCEEDED(hr)) {
        hr = MFSetAttributeRatio(decoded_video_type.Get(), MF_MT_FRAME_RATE,
                                 frame_rate_num, frame_rate_den);
      }
      if (SUCCEEDED(hr)) {
        hr = MFSetAttributeRatio(decoded_video_type.Get(),
                                 MF_MT_PIXEL_ASPECT_RATIO, pixel_ratio_num,
                                 pixel_ratio_den);
      }
      if (FAILED(hr)) {
        *error_message = HResultMessage(hr);
        break;
      }

      hr = reader->SetCurrentMediaType(video_input_stream, nullptr,
                                       decoded_video_type.Get());
      if (FAILED(hr)) {
        *error_message =
            L"Windows could not decode this video's video format.";
        break;
      }
      hr = reader->GetCurrentMediaType(video_input_stream,
                                       &video_input_type);
      if (FAILED(hr)) {
        *error_message = HResultMessage(hr);
        break;
      }
    }

    ComPtr<IMFMediaType> audio_input_type;
    if (audio_input_stream != kNoStream) {
      ComPtr<IMFMediaType> decoded_audio_type;
      hr = MFCreateMediaType(&decoded_audio_type);
      if (FAILED(hr)) {
        *error_message = HResultMessage(hr);
        break;
      }
      const bool input_ready =
          SetAudioGuid(decoded_audio_type.Get(), MF_MT_MAJOR_TYPE,
                       MFMediaType_Audio, error_message) &&
          SetAudioGuid(decoded_audio_type.Get(), MF_MT_SUBTYPE,
                       MFAudioFormat_PCM, error_message) &&
          SetAudioAttribute(decoded_audio_type.Get(),
                            MF_MT_AUDIO_NUM_CHANNELS, 2, error_message) &&
          SetAudioAttribute(decoded_audio_type.Get(),
                            MF_MT_AUDIO_SAMPLES_PER_SECOND, 44100,
                            error_message) &&
          SetAudioAttribute(decoded_audio_type.Get(),
                            MF_MT_AUDIO_BITS_PER_SAMPLE, 16, error_message) &&
          SetAudioAttribute(decoded_audio_type.Get(),
                            MF_MT_AUDIO_BLOCK_ALIGNMENT, 4, error_message) &&
          SetAudioAttribute(decoded_audio_type.Get(),
                            MF_MT_AUDIO_AVG_BYTES_PER_SECOND, 176400,
                            error_message);
      if (!input_ready) {
        break;
      }
      hr = reader->SetCurrentMediaType(audio_input_stream, nullptr,
                                       decoded_audio_type.Get());
      if (FAILED(hr)) {
        *error_message =
            L"Windows could not decode this media file's audio format.";
        break;
      }
      hr = reader->GetCurrentMediaType(audio_input_stream,
                                       &audio_input_type);
      if (FAILED(hr)) {
        *error_message = HResultMessage(hr);
        break;
      }
    }

    ComPtr<IMFSinkWriter> writer;
    hr = MFCreateSinkWriterFromURL(output_path.c_str(), nullptr, nullptr,
                                   &writer);
    if (FAILED(hr)) {
      *error_message = L"Windows could not create the MP4 output file.";
      break;
    }

    DWORD video_output_stream = kNoStream;
    if (video_input_stream != kNoStream) {
      ComPtr<IMFMediaType> encoded_video_type;
      hr = MFCreateMediaType(&encoded_video_type);
      if (FAILED(hr)) {
        *error_message = HResultMessage(hr);
        break;
      }
      hr = encoded_video_type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
      if (SUCCEEDED(hr)) {
        hr = encoded_video_type->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_H264);
      }
      if (SUCCEEDED(hr)) {
        hr = encoded_video_type->SetUINT32(MF_MT_INTERLACE_MODE,
                                           MFVideoInterlace_Progressive);
      }
      if (SUCCEEDED(hr)) {
        hr = MFSetAttributeSize(encoded_video_type.Get(), MF_MT_FRAME_SIZE,
                                frame_width, frame_height);
      }
      if (SUCCEEDED(hr)) {
        hr = MFSetAttributeRatio(encoded_video_type.Get(), MF_MT_FRAME_RATE,
                                 frame_rate_num, frame_rate_den);
      }
      if (SUCCEEDED(hr)) {
        hr = MFSetAttributeRatio(encoded_video_type.Get(),
                                 MF_MT_PIXEL_ASPECT_RATIO, pixel_ratio_num,
                                 pixel_ratio_den);
      }
      const UINT64 requested_bitrate =
          static_cast<UINT64>(frame_width) * frame_height * 6;
      const UINT32 video_bitrate = static_cast<UINT32>(
          std::clamp<UINT64>(requested_bitrate, 1000000, 16000000));
      if (SUCCEEDED(hr)) {
        hr = encoded_video_type->SetUINT32(MF_MT_AVG_BITRATE, video_bitrate);
      }
      if (FAILED(hr)) {
        *error_message = HResultMessage(hr);
        break;
      }
      hr = writer->AddStream(encoded_video_type.Get(), &video_output_stream);
      if (FAILED(hr)) {
        *error_message =
            L"The Windows H.264 encoder is unavailable on this device.";
        break;
      }
      hr = writer->SetInputMediaType(video_output_stream,
                                     video_input_type.Get(), nullptr);
      if (FAILED(hr)) {
        *error_message =
            L"The Windows H.264 encoder cannot use this video's format.";
        break;
      }
    }

    DWORD audio_output_stream = kNoStream;
    if (audio_input_stream != kNoStream) {
      ComPtr<IMFMediaType> encoded_audio_type;
      hr = MFCreateMediaType(&encoded_audio_type);
      if (FAILED(hr)) {
        *error_message = HResultMessage(hr);
        break;
      }
      hr = encoded_audio_type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
      if (SUCCEEDED(hr)) {
        hr = encoded_audio_type->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_AAC);
      }
      if (SUCCEEDED(hr)) {
        hr = encoded_audio_type->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
      }
      if (SUCCEEDED(hr)) {
        hr = encoded_audio_type->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND,
                                           44100);
      }
      if (SUCCEEDED(hr)) {
        hr = encoded_audio_type->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, 2);
      }
      if (SUCCEEDED(hr)) {
        hr = encoded_audio_type->SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND,
                                           20000);
      }
      if (SUCCEEDED(hr)) {
        hr = encoded_audio_type->SetUINT32(MF_MT_AUDIO_BLOCK_ALIGNMENT, 1);
      }
      if (SUCCEEDED(hr)) {
        hr = encoded_audio_type->SetUINT32(MF_MT_AAC_PAYLOAD_TYPE, 0);
      }
      if (FAILED(hr)) {
        *error_message = HResultMessage(hr);
        break;
      }
      hr = writer->AddStream(encoded_audio_type.Get(), &audio_output_stream);
      if (FAILED(hr)) {
        *error_message =
            L"The Windows AAC encoder is unavailable on this device.";
        break;
      }
      hr = writer->SetInputMediaType(audio_output_stream,
                                     audio_input_type.Get(), nullptr);
      if (FAILED(hr)) {
        *error_message =
            L"The Windows AAC encoder cannot use this media's audio format.";
        break;
      }
    }

    hr = writer->BeginWriting();
    if (FAILED(hr)) {
      *error_message = HResultMessage(hr);
      break;
    }

    bool video_done = video_input_stream == kNoStream;
    bool audio_done = audio_input_stream == kNoStream;
    bool read_error = false;
    while (!video_done || !audio_done) {
      DWORD actual_stream = 0;
      DWORD stream_flags = 0;
      LONGLONG timestamp = 0;
      ComPtr<IMFSample> sample;
      hr = reader->ReadSample(kAnyStream, 0, &actual_stream,
                              &stream_flags, &timestamp, &sample);
      if (FAILED(hr)) {
        *error_message = L"Windows could not read the media stream.";
        read_error = true;
        break;
      }
      if ((stream_flags & MF_SOURCE_READERF_ENDOFSTREAM) != 0) {
        if (actual_stream == video_input_stream) {
          video_done = true;
        } else if (actual_stream == audio_input_stream) {
          audio_done = true;
        } else if (actual_stream == kAnyStream) {
          video_done = true;
          audio_done = true;
        }
        continue;
      }
      if (sample == nullptr) {
        continue;
      }
      if (actual_stream == video_input_stream) {
        hr = writer->WriteSample(video_output_stream, sample.Get());
      } else if (actual_stream == audio_input_stream) {
        hr = writer->WriteSample(audio_output_stream, sample.Get());
      } else {
        continue;
      }
      if (FAILED(hr)) {
        *error_message = L"Windows could not encode this media stream.";
        read_error = true;
        break;
      }
    }

    if (read_error) {
      break;
    }
    hr = writer->Finalize();
    if (FAILED(hr)) {
      *error_message = L"Windows could not finish the MP4 file.";
      break;
    }
    success = true;
  } while (false);

  MFShutdown();
  CoUninitialize();

  if (!success) {
    std::error_code ignored;
    std::filesystem::remove(std::filesystem::path(output_path), ignored);
  }
  return success;
}

