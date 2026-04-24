# Milery App Site Map

```mermaid
graph TD
    A[MainTabView<br/>主導航] --> B[儀表板<br/>Dashboard]
    A --> C[進度<br/>Progress]
    A --> D[記帳<br/>Ledger]
    A --> E[里程碑<br/>Milestones]
    A --> F[設定<br/>Settings]

    %% Progress 子頁面
    C --> C1[新增目標<br/>AddFlightGoalView]
    C --> C2[編輯目標<br/>EditFlightGoalView]
    C --> C3[重新排序<br/>GoalReorderSheet]
    C --> C4[兌換確認<br/>RedeemSheet]

    %% Ledger 子頁面
    D --> D1[新增交易<br/>CalculatorLedgerView]
    D --> D2[編輯交易<br/>EditTransactionView]
    D --> D3[月份選擇器<br/>MonthSelector]

    %% Milestones 子頁面
    E --> E1[記錄兌換<br/>RecordSheet]

    %% Settings 子頁面
    F --> F1[背景圖片<br/>BackgroundPickerView]
    F --> F2[App Icon<br/>AppIconPickerView]
    F --> F3[信用卡管理<br/>CreditCardPageView]
    F --> F4[App密碼鎖<br/>AppLockSettingsView]
    F --> F5[通知設定<br/>NotificationSettingsView]
    F --> F6[好友系統<br/>FriendsView<br/>開發中]
    F --> F7[里程計劃切換<br/>ProgramSwitcherView<br/>開發中]

    %% 開發者選項
    F --> F8[機場資料列表<br/>AirportListView<br/>開發者]
    F --> F9[分頁顯示管理<br/>TabVisibilitySettingsView<br/>開發者]
    F --> F10[資料管理<br/>DataManagementView<br/>開發者]

    %% Settings Sheets
    F --> F11[機場選擇器<br/>AirportPicker]
    F --> F12[生日月份選擇器<br/>BirthdayPicker]
    F --> F13[彩蛋頁面<br/>EasterEgg]

    %% AppLockSettingsView 子頁面
    F4 --> F41[設定密碼<br/>SetPasscodeSheet]
    F4 --> F42[更改密碼<br/>ChangePasscodeSheet]

    %% FriendsView 子頁面
    F6 --> F61[新增好友<br/>AddFriendSheet]

    %% 樣式設定
    classDef main fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef sub fill:#f3e5f5,stroke:#4a148c,stroke-width:1px
    classDef dev fill:#fff3e0,stroke:#e65100,stroke-width:1px

    class A main
    class B,C,D,E,F sub
    class C1,C2,C3,C4,D1,D2,D3,E1,F1,F2,F3,F4,F5,F6,F7,F11,F12,F13,F41,F42,F61 sub
    class F8,F9,F10 dev
```</content>
<filePath">/Users/Sofia/Documents/GitHub/milery/site_map.md