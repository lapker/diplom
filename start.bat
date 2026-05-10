@echo off
chcp 65001 > nul
title FSN GALLERY CRM

echo.
echo  ============================================
echo    FSN GALLERY CRM — Запуск приложения
echo  ============================================
echo.

:: Проверяем наличие Python
python --version > nul 2>&1
if errorlevel 1 (
    echo  [ОШИБКА] Python не найден. Установите Python 3.10+
    echo  Скачать: https://www.python.org/downloads/
    pause
    exit /b 1
)

:: Устанавливаем зависимости
echo  [1/2] Установка зависимостей Python...
cd /d "%~dp0backend"
pip install -r requirements.txt -q --disable-pip-version-check
if errorlevel 1 (
    echo  [ОШИБКА] Не удалось установить зависимости
    pause
    exit /b 1
)

echo  [2/2] Запуск сервера...
echo.
echo  ============================================
echo    Приложение доступно по адресу:
echo.
echo    http://localhost:5000
echo.
echo    Нажмите Ctrl+C для остановки
echo  ============================================
echo.

:: Открываем браузер через 2 секунды
start "" /b cmd /c "timeout /t 2 /nobreak > nul && start http://localhost:5000"

:: Запускаем Flask
python app.py

pause
