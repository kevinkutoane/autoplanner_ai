import 'ai_provider.dart';

/// Mock AI provider for testing and offline development.
///
/// Returns canned responses so UI can be developed without
/// burning real API tokens.
class MockAIProvider implements AIProvider {
  @override
  final String modelName = 'mock-ai-v1';

  @override
  Future<AIResponse> complete(String prompt) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final lower = prompt.toLowerCase();

    String text;
    if (lower.contains('brain dump') || lower.contains('brain_dump')) {
      // Return the full structured object the parser expects.
      text = '''{
  "tasks": [
    {"title":"Review action items","startTime":"14:00","estimatedMinutes":30,"priority":1,"tags":["work"],"energyLevel":"medium"},
    {"title":"Deep work block","startTime":"14:30","estimatedMinutes":60,"priority":2,"tags":["focus"],"energyLevel":"high"}
  ],
  "notes": [
    {"title":"Project ideas","content":"Explore gamifying daily productivity with streak multipliers","tags":["idea"]}
  ],
  "goals": [
    {"title":"Launch MVP","description":"Ship version 1.0 of the planner"}
  ],
  "memories": [
    "User prefers focused work blocks in the afternoon."
  ]
}''';
    } else if (lower.contains('schedule assistant') ||
        lower.contains('user command:')) {
      if (lower.contains('push') ||
          lower.contains('delay') ||
          lower.contains('shift')) {
        text = '{"action":"shift","minutes":30,"explanation":"Shift upcoming tasks by 30 minutes."}';
      } else if (lower.contains('clear') || lower.contains('free')) {
        text = '{"action":"clear_window","fromTime":"14:00","toTime":"16:00","explanation":"Clear afternoon window from 2:00 PM to 4:00 PM."}';
      } else if (lower.contains('fit') || lower.contains('what can i do')) {
        text = '{"action":"find_fit","minutes":25,"explanation":"Find pending tasks fitting in 25 minutes."}';
      } else if (lower.contains('focus')) {
        text = '{"action":"start_focus","taskTitle":"Deep work block","explanation":"Start focus session on Deep work block."}';
      } else {
        text = '{"action":"quick_add","taskTitle":"Follow up with team","minutes":30,"priority":1,"tags":["work"],"explanation":"Add task Follow up with team."}';
      }
    } else if (lower.contains('extract') || lower.contains('memory')) {
      text = 'User prefers morning schedules and blocks deep work before noon.';
    } else if (lower.contains('insight') || lower.contains('daily')) {
      text = 'You tend to be most productive in the morning. Try scheduling your hardest task before 10am.';
    } else if (lower.contains('coach') ||
        lower.contains('autoplanner ai coach')) {
      if (lower.contains('structure') ||
          lower.contains('plan my day') ||
          lower.contains('plan')) {
        text = '''Here is a high-impact structure to maximize your productivity today:

🌅 **Morning Anchor (8:00 - 9:30 AM)**
• Review your Big 3 daily priorities over morning tea or coffee.
• Clear 1 quick administrative task to build early momentum.

🧠 **Deep Work Sprint (9:30 - 11:30 AM)**
• Lock in your hardest cognitive task while willpower is peaked.
• Turn on Do Not Disturb and activate AutoPlanner's Focus Hub.

🥪 **Recharge & Movement (12:00 - 1:00 PM)**
• Nutritious meal, physical movement, and disconnect from screens.

⚡ **Execution Block (1:30 - 4:00 PM)**
• Tackle team syncs, email responses, and secondary action items.

🏁 **Shutdown Ritual (4:30 - 5:00 PM)**
• Review completed tasks and brain dump tomorrow's attack plan!

Would you like me to help you schedule specific tasks or time blocks right now?''';
      } else if (lower.contains('procrastinat') ||
          lower.contains('stuck') ||
          lower.contains('resist')) {
        text = '''Overcoming friction starts with shrinking the ask:

1. **The 5-Minute Rule**: Commit to working on the task for just 5 minutes. You are free to stop afterwards, but 85% of people keep going once inertia breaks.
2. **Clarify the Micro-Step**: What is the literal physical next action? (e.g., "Open document and write title" instead of "Finish presentation").
3. **Trigger Focus Mode**: Tap the Focus tab and start a 25-minute Pomodoro session with gentle ambient sound.

Which task is causing the most resistance right now? Let's break it down together!''';
      } else if (lower.contains('cake') ||
          lower.contains('recipe') ||
          lower.contains('weather') ||
          lower.contains('movie') ||
          lower.contains('president')) {
        text = '''I am your **AutoPlanner AI Coach**! 🎯

My expertise is focused strictly on leveling up your productivity, designing daily schedules, defeating procrastination, and mastering your goals.

Let's channel this energy into your day — what's one priority or goal we can make progress on right now?''';
      } else {
        text = '''Great question! To make consistent progress, remember:

• **Prioritize with the Big 3**: Choose 3 non-negotiable wins for today.
• **Protect Deep Work**: Schedule uninterrupted focus blocks in AutoPlanner.
• **Capture Fleeting Ideas**: Tap the Brain Dump button anytime thoughts crowd your headspace.

How can I help you optimize your schedule or conquer your next milestone?''';
      }
    } else if (lower.contains('task') ||
        lower.contains('plan') ||
        lower.contains('schedule') ||
        lower.contains('enrich')) {
      text = '''[
  {"id": null, "title": "Morning review", "startTime": "08:00", "estimatedMinutes": 30, "priority": 1, "tags": ["work"]},
  {"id": null, "title": "Deep work block", "startTime": "09:00", "estimatedMinutes": 120, "priority": 2, "tags": ["focus"]},
  {"id": null, "title": "Lunch break", "startTime": "12:00", "estimatedMinutes": 60, "priority": 0, "tags": ["personal"]}
]''';
    } else if (lower.contains('summarize') || lower.contains('summary')) {
      text = 'This note covers key project decisions and action items from the team sync.';
    } else if (lower.contains('tag')) {
      text = '["productivity", "planning", "ai"]';
    } else {
      text =
          'Mock AI response for: ${prompt.substring(0, prompt.length.clamp(0, 50))}';
    }

    return AIResponse(
      text: text,
      promptTokens: (prompt.length / 4).ceil(),
      completionTokens: (text.length / 4).ceil(),
      latencyMs: 300,
      model: modelName,
    );
  }

  /// Emit in small chunks with a tiny delay —
  /// gives a realistic streaming feel during development.
  @override
  Stream<String> streamComplete(String prompt) async* {
    final response = await complete(prompt);
    const chunkSize = 4;
    final text = response.text;
    for (var i = 0; i < text.length; i += chunkSize) {
      yield text.substring(i, (i + chunkSize).clamp(0, text.length));
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  @override
  void dispose() {}
}
