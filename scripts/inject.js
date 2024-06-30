const originalReadText = navigator.clipboard.readText;

navigator.clipboard.readText = function () {
    console.log("Intercepted clipboard read");
    return Android.getClipboardData();
    // 调用原始方法
    return originalReadText.call(navigator.clipboard).then(text => {
        console.log("Clipboard content:", text);
        // 这里可以修改或处理文本
        return text;
    });
};