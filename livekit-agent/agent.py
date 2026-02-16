import logging
import pybars
import json
import asyncio
import time
import io
import base64
import re
import uuid
from typing import Awaitable, Callable
from dotenv import load_dotenv
from livekit import rtc
from livekit.agents import (
    Agent,
    AgentServer,
    AgentSession,
    AudioConfig,
    BackgroundAudioPlayer,
    BuiltinAudioClip,
    JobContext,
    JobProcess,
    cli,
    inference,
    room_io,
    llm,
)
from livekit.plugins import (
    noise_cancellation,
    silero,
)
from livekit.plugins.turn_detector.multilingual import MultilingualModel
try:
    from PIL import Image, ImageDraw, ImageFont
except Exception:  # pragma: no cover - optional runtime dependency fallback
    Image = None
    ImageDraw = None
    ImageFont = None

logger = logging.getLogger("agent-Alluwal")
WHITEBOARD_PROJECT_TOPICS = {"ai_tutor_whiteboard", "alluwal_whiteboard"}
WHITEBOARD_IMAGE_TOPIC = "whiteboard_image"
WHITEBOARD_MSG_TYPE_PROJECT = "project"
WHITEBOARD_MSG_TYPE_STUDENT_DRAWING_PERMISSION = "student_drawing_permission"
TEACHER_ACTION_TOPIC = "ai_tutor_teacher_actions"
TEACHER_ACTION_RESULT_TOPIC = "ai_tutor_teacher_action_results"
TEACHER_ACTION_MSG_TYPE = "teacher_action"
TEACHER_ACTION_RESULT_MSG_TYPE = "teacher_action_result"

load_dotenv(".env.local")


class VariableTemplater:
    def __init__(self, metadata: str, additional: dict[str, dict[str, str]] | None = None) -> None:
        self.variables = {
            "metadata": self._parse_metadata(metadata),
        }
        if additional:
            self.variables.update(additional)
        self._cache = {}
        self._compiler = pybars.Compiler()

    def _parse_metadata(self, metadata: str) -> dict:
        try:
            value = json.loads(metadata)
            if isinstance(value, dict):
                return value
            else:
                logger.warning(f"Job metadata is not a JSON dict: {metadata}")
                return {}
        except json.JSONDecodeError:
            return {}

    def _compile(self, template: str):
        if template in self._cache:
            return self._cache[template]
        self._cache[template] = self._compiler.compile(template)
        return self._cache[template]

    def render(self, template: str):
        return self._compile(template)(self.variables)


class DefaultAgent(Agent):
    def __init__(self, metadata: str) -> None:
        self._templater = VariableTemplater(metadata)
        self._metadata = metadata
        metadata_dict = self._templater.variables.get("metadata")
        if not isinstance(metadata_dict, dict):
            metadata_dict = {}
        self._metadata_dict = metadata_dict
        self._user_role = (
            str(
                metadata_dict.get("user_role")
                or metadata_dict.get("role")
                or ""
            )
            .strip()
            .lower()
        )
        self._publish_whiteboard_message_cb: Callable[[dict], Awaitable[None]] | None = None
        self._get_whiteboard_project_cb: Callable[[], dict] | None = None
        self._request_teacher_action_cb: Callable[[str, dict], Awaitable[dict]] | None = None
        super().__init__(
            instructions=self._templater.render("""
  Muslim Professional Tutor Agent (Islamic Tutor for Children)

  STUDENT INFORMATION: You are currently tutoring a student named {{metadata.user_name}}. Remember and use their name naturally throughout the conversation.

  STUDENT CLASS SCHEDULE: {{metadata.class_schedule}}
  CLASS SCHEDULE STATUS: {{metadata.class_schedule_status}}
  Schedule handling rule: If the student asks about their classes or schedule, answer directly using the STUDENT CLASS SCHEDULE text above before asking any follow-up question.
  If the schedule text says "No upcoming classes scheduled." or "Unable to load class schedule.", state that clearly and then offer to help them plan study time.
  Access confirmation rule: If the student asks whether you have access to their class schedule, answer yes. Then quote or summarize the STUDENT CLASS SCHEDULE you were given. Only say schedule access is unavailable when CLASS SCHEDULE STATUS is "unavailable".
  SESSION ROLE: {{metadata.user_role}}
  Role handling rules:
  - If SESSION ROLE is teacher, treat {{metadata.user_name}} as a teacher and not as a student.
  - For teacher requests like "clock me in" or class time changes, use the teacher tools.
  - Only confirm teacher clock-in/reschedule as completed when tool results report success.
  - If SESSION ROLE is student, keep normal tutoring behavior.
  - Teacher scheduling safety: before changing class times, ask whether the teacher means today only or all future classes for that student if unclear, then summarize and get explicit confirmation before calling a write tool.
  - Teacher timezone rule: interpret all teacher schedule times in {{metadata.user_timezone}} unless the teacher gives a different timezone.

  Role and purpose: You are Alluwal, a Muslim professional tutor who teaches children with kindness, clarity, and strong Islamic adab (ah-dahb). Your goal is to help {{metadata.user_name}} learn school topics and, whenever appropriate, connect learning to Islamic values, akhlaq (akh-lahk), and age-appropriate stories from the Qur'an (kor-AHN) and the Sunnah (SOON-nah) without harshness or fear-based teaching. You have access to {{metadata.user_name}}'s class schedule and can help them prepare for upcoming classes or remind them about their schedule when asked.

  VISION CAPABILITY: You can see what the student draws on their whiteboard. When they show you their whiteboard, analyze their work carefully and provide helpful feedback. If they are solving math problems, check their work step by step. If they are drawing diagrams, help them understand the concepts. Always be encouraging while gently correcting any mistakes.

  Islamic alignment: Treat Islam as true and guiding; answer through the lens of Islamic knowledge and good character. Use well-known, mainstream teachings; when there are differences of scholarly opinion, mention that more than one view exists in a gentle way and encourage asking a trusted parent, teacher, or local imam (ih-MAHM) for personal rulings. Do not pretend to be a mufti; if asked for a strict legal verdict (fat-wah, FAHT-wah) about a personal situation, give general guidance, emphasize intention (nee-YAH), and suggest speaking to a qualified scholar.

  Teaching persona and style: Be warm, patient, and encouraging while still being honest; praise {{metadata.user_name}}'s effort, but do not blindly agree if they are mistaken. Use child-friendly language and simple analogies. Prefer guided discovery: ask small, leading questions that help {{metadata.user_name}} think, rather than delivering long lectures. Break ideas into tiny steps, check understanding before moving on, and end learning moments with a short takeaway in simple words.

  Output rules for voice mastery (must follow every turn): Respond in plain text only with no markdown, no emojis, and no list formatting. Keep each reply to one to three sentences. Always end your turn with exactly one question to keep the lesson moving. Spell out numbers as words. When using Arabic or Islamic terms that might be hard to pronounce, include a phonetic spelling in parentheses the first time you use the term in the conversation; avoid Arabic script to prevent speech errors.

  Conversation flow: Start by learning {{metadata.user_name}}'s age or grade level and what they want to learn today. If they ask about their schedule, refer to their class schedule information. Teach in short steps; after each step, ask a single question to confirm understanding or invite {{metadata.user_name}} to apply the idea. If they show confusion, re-explain with an easier example and try again. When {{metadata.user_name}} wants an Islamic story, focus on the moral lesson and how to practice it today. When they ask about sensitive topics, respond with calm adab, keep it age-appropriate, and redirect to a safe and constructive learning point.

  Whiteboard interaction tools: You can directly interact with the shared whiteboard. Use whiteboard_set_student_drawing to lock or unlock student drawing, whiteboard_draw_line and whiteboard_draw_rectangle for geometry, whiteboard_write_equation and whiteboard_write_text for clean writing, whiteboard_erase_last for undo, and whiteboard_clear to reset the board. When the student asks you to draw or write on the board, call these tools instead of only describing the action. For equations, prefer whiteboard_write_equation so expressions render clearly. For multi-step board updates, lock student drawing first, do the board actions, then unlock student drawing.
  Teacher operational tools: For teacher sessions, use teacher_clock_me_in to clock into class and teacher_reschedule_class to change class times. Never execute a schedule change without explicit confirmation from the teacher and a clear scope (single class or all future classes).

  Boundaries and safety: Never promote harm, hatred, or disrespect toward any people. If {{metadata.user_name}} asks for something inappropriate or dangerous, refuse gently, explain the safer path, and steer back to learning and good character. For medical, legal, or urgent personal issues, encourage them to speak to a trusted adult and provide only general, safety-first guidance.

  Recommended welcome message: As-salamu alaykum {{metadata.user_name}} I am so excited to be your learning buddy today. We can talk about school subjects or explore beautiful stories from Islamic history. What would you like to learn about first?"""),
        )

    def configure_whiteboard_bridge(
        self,
        *,
        publish_message_cb: Callable[[dict], Awaitable[None]],
        get_project_cb: Callable[[], dict],
    ) -> None:
        self._publish_whiteboard_message_cb = publish_message_cb
        self._get_whiteboard_project_cb = get_project_cb

    def configure_teacher_action_bridge(
        self,
        *,
        request_action_cb: Callable[[str, dict], Awaitable[dict]],
    ) -> None:
        self._request_teacher_action_cb = request_action_cb

    def _require_teacher_action_bridge(
        self,
    ) -> Callable[[str, dict], Awaitable[dict]]:
        if self._user_role != "teacher":
            raise llm.ToolError(
                "teacher actions are only available in teacher sessions"
            )
        if self._request_teacher_action_cb is None:
            raise llm.ToolError("teacher action bridge is not initialized")
        return self._request_teacher_action_cb

    async def _execute_teacher_action(
        self,
        *,
        action: str,
        args: dict,
    ) -> dict:
        request_action = self._require_teacher_action_bridge()
        result = await request_action(action, args)
        if not isinstance(result, dict):
            raise llm.ToolError("invalid response from teacher action executor")
        return result

    def _clamp01(self, value: float) -> float:
        return max(0.0, min(1.0, float(value)))

    def _require_whiteboard_bridge(
        self,
    ) -> tuple[Callable[[dict], Awaitable[None]], Callable[[], dict]]:
        if self._publish_whiteboard_message_cb is None or self._get_whiteboard_project_cb is None:
            raise llm.ToolError("whiteboard bridge is not initialized")
        return self._publish_whiteboard_message_cb, self._get_whiteboard_project_cb

    def _new_stroke(
        self,
        points: list[dict[str, float]],
        *,
        color_argb: int,
        stroke_width: float,
    ) -> dict:
        return {
            "id": f"agent_{int(time.time() * 1000)}_{len(points)}",
            "points": points,
            "color": int(color_argb),
            "strokeWidth": float(stroke_width),
            "normalized": True,
        }

    def _new_text_item(
        self,
        *,
        text: str,
        x: float,
        y: float,
        color_argb: int,
        font_size: float,
    ) -> dict:
        clean_text = text.strip()
        if not clean_text:
            raise llm.ToolError("text cannot be empty")
        return {
            "id": f"agent_text_{int(time.time() * 1000)}_{len(clean_text)}",
            "text": clean_text[:220],
            "x": self._clamp01(x),
            "y": self._clamp01(y),
            "color": int(color_argb),
            "fontSize": float(max(12.0, min(72.0, font_size))),
            "normalized": True,
        }

    def _ensure_project_lists(self, project: dict) -> tuple[list, list]:
        strokes = project.get("strokes")
        if not isinstance(strokes, list):
            strokes = []
            project["strokes"] = strokes

        texts = project.get("texts")
        if not isinstance(texts, list):
            texts = []
            project["texts"] = texts

        return strokes, texts

    def _extract_item_timestamp(self, item_id: str | None, fallback: int) -> int:
        if not item_id:
            return fallback
        match = re.search(r"(\d{9,})", item_id)
        if match is None:
            return fallback
        try:
            return int(match.group(1))
        except Exception:
            return fallback

    @llm.function_tool(
        description="Enable or disable the student's ability to draw on the shared whiteboard."
    )
    async def whiteboard_set_student_drawing(self, enabled: bool) -> str:
        publish_message, _ = self._require_whiteboard_bridge()
        await publish_message(
            {
                "type": WHITEBOARD_MSG_TYPE_STUDENT_DRAWING_PERMISSION,
                "payload": {"enabled": bool(enabled)},
            }
        )
        return (
            "Student drawing enabled."
            if enabled
            else "Student drawing disabled while the agent draws."
        )

    @llm.function_tool(
        description="Draw a straight line on the whiteboard using normalized coordinates between zero and one."
    )
    async def whiteboard_draw_line(
        self,
        x1: float,
        y1: float,
        x2: float,
        y2: float,
        color_argb: int = 0xFF0E72ED,
        stroke_width: float = 4.0,
        lock_student_while_drawing: bool = True,
    ) -> str:
        publish_message, get_project = self._require_whiteboard_bridge()
        if lock_student_while_drawing:
            await publish_message(
                {
                    "type": WHITEBOARD_MSG_TYPE_STUDENT_DRAWING_PERMISSION,
                    "payload": {"enabled": False},
                }
            )

        try:
            project = get_project()
            strokes, _ = self._ensure_project_lists(project)

            line_points = [
                {"x": self._clamp01(x1), "y": self._clamp01(y1)},
                {"x": self._clamp01(x2), "y": self._clamp01(y2)},
            ]
            strokes.append(
                self._new_stroke(
                    line_points,
                    color_argb=color_argb,
                    stroke_width=stroke_width,
                )
            )
            project["version"] = 2
            await publish_message(
                {"type": WHITEBOARD_MSG_TYPE_PROJECT, "payload": project}
            )
        finally:
            if lock_student_while_drawing:
                await publish_message(
                    {
                        "type": WHITEBOARD_MSG_TYPE_STUDENT_DRAWING_PERMISSION,
                        "payload": {"enabled": True},
                    }
                )

        return "Drew a line on the whiteboard."

    @llm.function_tool(
        description="Draw a rectangle on the whiteboard using normalized coordinates between zero and one."
    )
    async def whiteboard_draw_rectangle(
        self,
        x1: float,
        y1: float,
        x2: float,
        y2: float,
        color_argb: int = 0xFF0E72ED,
        stroke_width: float = 4.0,
        lock_student_while_drawing: bool = True,
    ) -> str:
        publish_message, get_project = self._require_whiteboard_bridge()
        if lock_student_while_drawing:
            await publish_message(
                {
                    "type": WHITEBOARD_MSG_TYPE_STUDENT_DRAWING_PERMISSION,
                    "payload": {"enabled": False},
                }
            )

        try:
            ax = self._clamp01(min(x1, x2))
            ay = self._clamp01(min(y1, y2))
            bx = self._clamp01(max(x1, x2))
            by = self._clamp01(max(y1, y2))

            project = get_project()
            strokes, _ = self._ensure_project_lists(project)

            rect_points = [
                {"x": ax, "y": ay},
                {"x": bx, "y": ay},
                {"x": bx, "y": by},
                {"x": ax, "y": by},
                {"x": ax, "y": ay},
            ]
            strokes.append(
                self._new_stroke(
                    rect_points,
                    color_argb=color_argb,
                    stroke_width=stroke_width,
                )
            )
            project["version"] = 2
            await publish_message(
                {"type": WHITEBOARD_MSG_TYPE_PROJECT, "payload": project}
            )
        finally:
            if lock_student_while_drawing:
                await publish_message(
                    {
                        "type": WHITEBOARD_MSG_TYPE_STUDENT_DRAWING_PERMISSION,
                        "payload": {"enabled": True},
                    }
                )

        return "Drew a rectangle on the whiteboard."

    @llm.function_tool(
        description=(
            "Write clean text on the whiteboard at normalized coordinates between zero and one. "
            "Use this for labels, definitions, and equations."
        )
    )
    async def whiteboard_write_text(
        self,
        text: str,
        x: float,
        y: float,
        color_argb: int = 0xFF111827,
        font_size: float = 34.0,
        lock_student_while_writing: bool = True,
    ) -> str:
        publish_message, get_project = self._require_whiteboard_bridge()
        if lock_student_while_writing:
            await publish_message(
                {
                    "type": WHITEBOARD_MSG_TYPE_STUDENT_DRAWING_PERMISSION,
                    "payload": {"enabled": False},
                }
            )

        try:
            project = get_project()
            _, texts = self._ensure_project_lists(project)
            texts.append(
                self._new_text_item(
                    text=text,
                    x=x,
                    y=y,
                    color_argb=color_argb,
                    font_size=font_size,
                )
            )
            project["version"] = 2
            await publish_message(
                {"type": WHITEBOARD_MSG_TYPE_PROJECT, "payload": project}
            )
        finally:
            if lock_student_while_writing:
                await publish_message(
                    {
                        "type": WHITEBOARD_MSG_TYPE_STUDENT_DRAWING_PERMISSION,
                        "payload": {"enabled": True},
                    }
                )

        return "Wrote text on the whiteboard."

    @llm.function_tool(
        description=(
            "Write a math equation cleanly on the whiteboard. "
            "Use caret notation for powers like x^2 and underscore notation for subscripts like a_1."
        )
    )
    async def whiteboard_write_equation(
        self,
        equation: str,
        x: float,
        y: float,
        font_size: float = 38.0,
        color_argb: int = 0xFF111827,
        lock_student_while_writing: bool = True,
    ) -> str:
        publish_message, get_project = self._require_whiteboard_bridge()
        if lock_student_while_writing:
            await publish_message(
                {
                    "type": WHITEBOARD_MSG_TYPE_STUDENT_DRAWING_PERMISSION,
                    "payload": {"enabled": False},
                }
            )

        try:
            project = get_project()
            _, texts = self._ensure_project_lists(project)
            texts.append(
                self._new_text_item(
                    text=equation,
                    x=x,
                    y=y,
                    color_argb=color_argb,
                    font_size=font_size,
                )
            )
            project["version"] = 2
            await publish_message(
                {"type": WHITEBOARD_MSG_TYPE_PROJECT, "payload": project}
            )
        finally:
            if lock_student_while_writing:
                await publish_message(
                    {
                        "type": WHITEBOARD_MSG_TYPE_STUDENT_DRAWING_PERMISSION,
                        "payload": {"enabled": True},
                    }
                )

        return "Wrote an equation on the whiteboard."

    @llm.function_tool(
        description=(
            "Erase the last few whiteboard items. "
            "Use target='any' to remove whichever elements were added most recently across strokes and text."
        )
    )
    async def whiteboard_erase_last(
        self,
        count: int = 1,
        target: str = "any",
        lock_student_while_drawing: bool = True,
    ) -> str:
        publish_message, get_project = self._require_whiteboard_bridge()
        safe_count = max(1, min(int(count), 50))

        if lock_student_while_drawing:
            await publish_message(
                {
                    "type": WHITEBOARD_MSG_TYPE_STUDENT_DRAWING_PERMISSION,
                    "payload": {"enabled": False},
                }
            )

        try:
            project = get_project()
            strokes, texts = self._ensure_project_lists(project)
            normalized_target = (target or "any").strip().lower()
            removed_strokes = 0
            removed_texts = 0

            if normalized_target == "strokes":
                remove_count = min(safe_count, len(strokes))
                if remove_count > 0:
                    del strokes[-remove_count:]
                removed_strokes = remove_count
            elif normalized_target in {"texts", "text"}:
                remove_count = min(safe_count, len(texts))
                if remove_count > 0:
                    del texts[-remove_count:]
                removed_texts = remove_count
            else:
                # Remove recent items across both lists by ID timestamp.
                combined_items: list[tuple[int, str, int]] = []
                for idx, stroke in enumerate(strokes):
                    item_id = (
                        str(stroke.get("id"))
                        if isinstance(stroke, dict) and stroke.get("id") is not None
                        else None
                    )
                    combined_items.append(
                        (self._extract_item_timestamp(item_id, idx), "stroke", idx)
                    )
                for idx, text_item in enumerate(texts):
                    item_id = (
                        str(text_item.get("id"))
                        if isinstance(text_item, dict)
                        and text_item.get("id") is not None
                        else None
                    )
                    combined_items.append(
                        (self._extract_item_timestamp(item_id, idx), "text", idx)
                    )

                combined_items.sort(key=lambda item: (item[0], item[2]), reverse=True)
                to_remove = combined_items[:safe_count]
                stroke_indexes_to_remove = {
                    idx for _, kind, idx in to_remove if kind == "stroke"
                }
                text_indexes_to_remove = {
                    idx for _, kind, idx in to_remove if kind == "text"
                }

                if stroke_indexes_to_remove:
                    strokes[:] = [
                        stroke
                        for idx, stroke in enumerate(strokes)
                        if idx not in stroke_indexes_to_remove
                    ]
                if text_indexes_to_remove:
                    texts[:] = [
                        text_item
                        for idx, text_item in enumerate(texts)
                        if idx not in text_indexes_to_remove
                    ]

                removed_strokes = len(stroke_indexes_to_remove)
                removed_texts = len(text_indexes_to_remove)

            project["strokes"] = strokes
            project["texts"] = texts
            project["version"] = 2
            await publish_message(
                {"type": WHITEBOARD_MSG_TYPE_PROJECT, "payload": project}
            )
        finally:
            if lock_student_while_drawing:
                await publish_message(
                    {
                        "type": WHITEBOARD_MSG_TYPE_STUDENT_DRAWING_PERMISSION,
                        "payload": {"enabled": True},
                    }
                )

        return (
            "Erased "
            f"{removed_strokes} stroke(s) and {removed_texts} text item(s) "
            "from the whiteboard."
        )

    @llm.function_tool(
        description="Clear all whiteboard strokes and text."
    )
    async def whiteboard_clear(self, lock_student_while_drawing: bool = True) -> str:
        publish_message, _ = self._require_whiteboard_bridge()

        if lock_student_while_drawing:
            await publish_message(
                {
                    "type": WHITEBOARD_MSG_TYPE_STUDENT_DRAWING_PERMISSION,
                    "payload": {"enabled": False},
                }
            )

        try:
            await publish_message(
                {
                    "type": WHITEBOARD_MSG_TYPE_PROJECT,
                    "payload": {"strokes": [], "texts": [], "version": 2},
                }
            )
        finally:
            if lock_student_while_drawing:
                await publish_message(
                    {
                        "type": WHITEBOARD_MSG_TYPE_STUDENT_DRAWING_PERMISSION,
                        "payload": {"enabled": True},
                    }
                )

        return "Cleared the whiteboard."

    @llm.function_tool(
        description=(
            "Clock the teacher into class. "
            "Use this when the teacher says clock me in."
        )
    )
    async def teacher_clock_me_in(self, shift_id: str = "") -> str:
        args: dict[str, str] = {}
        if shift_id.strip():
            args["shiftId"] = shift_id.strip()

        result = await self._execute_teacher_action(action="clock_in", args=args)
        success = result.get("success") is True
        message = str(result.get("message") or "").strip()
        if success:
            return message or "Clock-in completed successfully."
        raise llm.ToolError(message or "Clock-in failed.")

    @llm.function_tool(
        description=(
            "Reschedule a class for a teacher. "
            "Requires local datetime values, explicit scope, and explicit confirmation."
        )
    )
    async def teacher_reschedule_class(
        self,
        new_start_local_iso: str,
        new_end_local_iso: str,
        scope: str,
        confirmed: bool,
        shift_id: str = "",
        student_name: str = "",
        student_id: str = "",
        apply_from_local_iso: str = "",
        timezone: str = "",
        reason: str = "",
    ) -> str:
        normalized_scope = scope.strip().lower()
        if normalized_scope in {"today", "today_only", "one_time", "single"}:
            normalized_scope = "single"
        elif normalized_scope in {
            "future",
            "all_future",
            "series",
            "recurring",
        }:
            normalized_scope = "future"
        else:
            raise llm.ToolError(
                "Before I reschedule, tell me if this is for today only or all future classes."
            )

        if confirmed is not True:
            raise llm.ToolError(
                "Please explicitly confirm before I make this schedule change."
            )

        resolved_timezone = timezone.strip()
        if not resolved_timezone:
            resolved_timezone = str(
                self._metadata_dict.get("user_timezone") or "UTC"
            ).strip() or "UTC"

        args: dict[str, object] = {
            "scope": normalized_scope,
            "confirmed": True,
            "newStartLocal": new_start_local_iso.strip(),
            "newEndLocal": new_end_local_iso.strip(),
            "timezone": resolved_timezone,
        }
        if shift_id.strip():
            args["shiftId"] = shift_id.strip()
        if student_name.strip():
            args["studentName"] = student_name.strip()
        if student_id.strip():
            args["studentId"] = student_id.strip()
        if apply_from_local_iso.strip():
            args["applyFromDate"] = apply_from_local_iso.strip()
        if reason.strip():
            args["reason"] = reason.strip()

        action_name = (
            "reschedule_shift_future"
            if normalized_scope == "future"
            else "reschedule_shift"
        )
        result = await self._execute_teacher_action(
            action=action_name,
            args=args,
        )
        success = result.get("success") is True
        message = str(result.get("message") or "").strip()
        if success:
            return message or "Class time changed successfully."
        raise llm.ToolError(message or "Reschedule failed.")

    def get_greeting_instructions(self) -> str:
        if self._user_role == "teacher":
            return self._templater.render(
                """Greet the teacher warmly. Address them as {{metadata.user_name}}. Mention that you can help with schedule questions, class time changes, and clock-in actions."""
            )
        return self._templater.render(
            """Greet the user warmly. Address them as {{metadata.user_name}}. Offer your assistance as their learning buddy."""
        )


server = AgentServer()

def prewarm(proc: JobProcess):
    proc.userdata["vad"] = silero.VAD.load()

server.setup_fnc = prewarm

@server.rtc_session(agent_name="Alluwal")
async def entrypoint(ctx: JobContext):
    # Connect to the room first
    await ctx.connect()

    session = AgentSession(
        stt=inference.STT(model="cartesia/ink-whisper", language="en"),
        llm=inference.LLM(model="openai/gpt-4o"),
        tts=inference.TTS(
            model="cartesia/sonic-3",
            voice="a167e0f3-df7e-4d52-a9c3-f949145efdab",
            language="en"
        ),
        turn_detection=MultilingualModel(),
        vad=ctx.proc.userdata["vad"],
        preemptive_generation=True,
    )

    agent = DefaultAgent(metadata=ctx.job.metadata)

    await session.start(
        agent=agent,
        room=ctx.room,
        room_options=room_io.RoomOptions(
            audio_input=room_io.AudioInputOptions(
                noise_cancellation=lambda params: noise_cancellation.BVCTelephony() if params.participant.kind == rtc.ParticipantKind.PARTICIPANT_KIND_SIP else noise_cancellation.BVC(),
            ),
            # VISION ENABLED: Agent can see video/images
            video_input=True,
        ),
    )

    whiteboard_state: dict[str, object] = {
        "last_stroke_ids": set(),
        "last_text_ids": set(),
        "last_feedback_at": 0.0,
        "last_project": None,
    }
    pending_whiteboard_task: asyncio.Task | None = None
    pending_teacher_action_results: dict[str, asyncio.Future] = {}

    def _clone_project(project: dict) -> dict:
        return json.loads(json.dumps(project))

    def _get_current_project() -> dict:
        project = whiteboard_state.get("last_project")
        if isinstance(project, dict):
            try:
                cloned = _clone_project(project)
                strokes = cloned.get("strokes")
                texts = cloned.get("texts")
                if not isinstance(strokes, list):
                    strokes = []
                    cloned["strokes"] = strokes
                if not isinstance(texts, list):
                    texts = []
                    cloned["texts"] = texts
                cloned["version"] = 2
                return cloned
            except Exception:
                pass
        return {"strokes": [], "texts": [], "version": 2}

    def _extract_ids_from_items(project: dict, key: str) -> set[str]:
        items = project.get(key)
        if not isinstance(items, list):
            return set()
        ids: set[str] = set()
        for item in items:
            if isinstance(item, dict) and item.get("id") is not None:
                ids.add(str(item.get("id")))
        return ids

    async def _publish_whiteboard_message(message: dict) -> None:
        local = ctx.room.local_participant
        if local is None:
            raise llm.ToolError("local participant is not available")

        encoded = json.dumps(message)
        for topic in WHITEBOARD_PROJECT_TOPICS:
            await local.publish_data(
                encoded,
                reliable=True,
                topic=topic,
            )

        if message.get("type") == WHITEBOARD_MSG_TYPE_PROJECT and isinstance(
            message.get("payload"), dict
        ):
            payload = _clone_project(message["payload"])
            if not isinstance(payload.get("strokes"), list):
                payload["strokes"] = []
            if not isinstance(payload.get("texts"), list):
                payload["texts"] = []
            whiteboard_state["last_project"] = payload
            whiteboard_state["last_stroke_ids"] = _extract_ids_from_items(
                payload, "strokes"
            )
            whiteboard_state["last_text_ids"] = _extract_ids_from_items(
                payload, "texts"
            )

    agent.configure_whiteboard_bridge(
        publish_message_cb=_publish_whiteboard_message,
        get_project_cb=_get_current_project,
    )

    async def _request_teacher_action(action: str, args: dict) -> dict:
        local = ctx.room.local_participant
        if local is None:
            raise llm.ToolError("local participant is not available")

        request_id = f"teacher_action_{int(time.time() * 1000)}_{uuid.uuid4().hex[:8]}"
        payload = {
            "type": TEACHER_ACTION_MSG_TYPE,
            "payload": {
                "requestId": request_id,
                "action": action,
                "args": args if isinstance(args, dict) else {},
            },
        }

        loop = asyncio.get_running_loop()
        result_future: asyncio.Future = loop.create_future()
        pending_teacher_action_results[request_id] = result_future

        try:
            await local.publish_data(
                json.dumps(payload),
                reliable=True,
                topic=TEACHER_ACTION_TOPIC,
            )
            logger.info(
                f"Teacher actions: published action={action} request_id={request_id}"
            )
            raw_result = await asyncio.wait_for(result_future, timeout=25.0)
        except asyncio.TimeoutError:
            logger.warning(
                f"Teacher actions: timeout waiting for request_id={request_id}"
            )
            return {
                "success": False,
                "message": "I could not confirm the action in time. Please try again.",
            }
        finally:
            pending_teacher_action_results.pop(request_id, None)

        if isinstance(raw_result, dict):
            return raw_result
        return {
            "success": False,
            "message": "Received an invalid response for the teacher action.",
        }

    agent.configure_teacher_action_bridge(
        request_action_cb=_request_teacher_action,
    )

    def _parse_whiteboard_project(data: bytes) -> dict | None:
        try:
            packet_json = json.loads(data.decode("utf-8"))
        except Exception as e:
            logger.warning(f"Whiteboard: failed to parse packet JSON: {e}")
            return None

        if not isinstance(packet_json, dict):
            return None

        msg_type = packet_json.get("type")
        payload = packet_json.get("payload")
        if msg_type != WHITEBOARD_MSG_TYPE_PROJECT or not isinstance(payload, dict):
            return None

        strokes = payload.get("strokes")
        if not isinstance(strokes, list):
            return None

        texts = payload.get("texts")
        if texts is None:
            payload["texts"] = []
        elif not isinstance(texts, list):
            return None

        return payload

    def _parse_teacher_action_result(data: bytes) -> dict | None:
        try:
            packet_json = json.loads(data.decode("utf-8"))
        except Exception as e:
            logger.warning(f"Teacher actions: failed to parse packet JSON: {e}")
            return None

        if not isinstance(packet_json, dict):
            return None
        if packet_json.get("type") != TEACHER_ACTION_RESULT_MSG_TYPE:
            return None

        payload = packet_json.get("payload")
        if not isinstance(payload, dict):
            return None
        return payload

    def _summarize_project(project: dict, action: str) -> str:
        strokes = project.get("strokes") or []
        if not isinstance(strokes, list):
            strokes = []
        texts = project.get("texts") or []
        if not isinstance(texts, list):
            texts = []

        stroke_count = len(strokes)
        text_count = len(texts)
        point_count = 0
        min_x, min_y = 1.0, 1.0
        max_x, max_y = 0.0, 0.0
        colors: list[str] = []

        for stroke in strokes:
            if not isinstance(stroke, dict):
                continue
            color = stroke.get("color")
            if color is not None and len(colors) < 6:
                colors.append(str(color))

            points = stroke.get("points") or []
            if not isinstance(points, list):
                continue
            point_count += len(points)
            for point in points:
                if not isinstance(point, dict):
                    continue
                x = point.get("x")
                y = point.get("y")
                if isinstance(x, (int, float)) and isinstance(y, (int, float)):
                    min_x = min(min_x, float(x))
                    min_y = min(min_y, float(y))
                    max_x = max(max_x, float(x))
                    max_y = max(max_y, float(y))

        if stroke_count == 0:
            bounds_text = "empty board"
        elif point_count == 0:
            bounds_text = "strokes present but no point data"
        else:
            bounds_text = (
                f"bounds normalized x {min_x:.2f} to {max_x:.2f}, "
                f"y {min_y:.2f} to {max_y:.2f}"
            )

        color_text = ", ".join(colors[:4]) if colors else "no color data"
        sample_text = ""
        for text_item in texts:
            if isinstance(text_item, dict):
                text_value = text_item.get("text")
                if isinstance(text_value, str) and text_value.strip():
                    sample_text = text_value.strip()[:80]
                    break

        return (
            f"Whiteboard update: action={action}. "
            f"strokes={stroke_count}. text_items={text_count}. points={point_count}. {bounds_text}. "
            f"sample colors={color_text}. "
            f"sample text={'none' if not sample_text else sample_text!r}."
        )

    def _parse_image_data_url_from_message(data: bytes) -> str | None:
        try:
            packet_json = json.loads(data.decode("utf-8"))
        except Exception as e:
            logger.warning(f"Whiteboard image: failed to parse JSON: {e}")
            return None

        if not isinstance(packet_json, dict):
            return None

        image_base64 = packet_json.get("image_base64")
        if not isinstance(image_base64, str) or not image_base64:
            return None

        if image_base64.startswith("data:"):
            return image_base64

        # Raw base64 string without prefix; default to PNG unless provided.
        mime_type = packet_json.get("mime_type")
        if not isinstance(mime_type, str) or not mime_type:
            mime_type = "image/png"

        try:
            # Validate the payload before building the data URL.
            base64.b64decode(image_base64, validate=True)
        except Exception as e:
            logger.warning(f"Whiteboard image: invalid base64 payload: {e}")
            return None

        return f"data:{mime_type};base64,{image_base64}"

    def _argb_to_rgba(argb: int) -> tuple[int, int, int, int]:
        a = (argb >> 24) & 0xFF
        r = (argb >> 16) & 0xFF
        g = (argb >> 8) & 0xFF
        b = argb & 0xFF
        return (r, g, b, a)

    def _render_project_png(
        project: dict, width: int = 1024, height: int = 768
    ) -> bytes | None:
        if Image is None or ImageDraw is None:
            logger.warning("Whiteboard: Pillow is unavailable; cannot render board image")
            return None

        strokes = project.get("strokes") or []
        if not isinstance(strokes, list):
            return None
        texts = project.get("texts") or []
        if not isinstance(texts, list):
            texts = []

        image = Image.new("RGBA", (width, height), (255, 255, 255, 255))
        draw = ImageDraw.Draw(image, "RGBA")

        for stroke in strokes:
            if not isinstance(stroke, dict):
                continue

            points = stroke.get("points") or []
            if not isinstance(points, list) or len(points) == 0:
                continue

            normalized = stroke.get("normalized") is True
            stroke_width_raw = stroke.get("strokeWidth", 3.0)
            try:
                stroke_width = max(1, int(float(stroke_width_raw)))
            except Exception:
                stroke_width = 3

            color_raw = stroke.get("color", 0xFF000000)
            try:
                color_rgba = _argb_to_rgba(int(color_raw))
            except Exception:
                color_rgba = (0, 0, 0, 255)

            canvas_points: list[tuple[float, float]] = []
            for point in points:
                if not isinstance(point, dict):
                    continue
                x = point.get("x")
                y = point.get("y")
                if not isinstance(x, (int, float)) or not isinstance(y, (int, float)):
                    continue
                px = float(x) * width if normalized else float(x)
                py = float(y) * height if normalized else float(y)
                canvas_points.append((px, py))

            if not canvas_points:
                continue

            if len(canvas_points) == 1:
                x, y = canvas_points[0]
                r = max(1.0, stroke_width / 2.0)
                draw.ellipse((x - r, y - r, x + r, y + r), fill=color_rgba)
            else:
                draw.line(canvas_points, fill=color_rgba, width=stroke_width, joint="curve")

        default_font = None
        if ImageFont is not None:
            try:
                default_font = ImageFont.truetype("DejaVuSans.ttf", size=32)
            except Exception:
                try:
                    default_font = ImageFont.load_default()
                except Exception:
                    default_font = None

        for text_item in texts:
            if not isinstance(text_item, dict):
                continue
            text_value = text_item.get("text")
            if not isinstance(text_value, str) or not text_value.strip():
                continue

            x_raw = text_item.get("x", 0.0)
            y_raw = text_item.get("y", 0.0)
            normalized = text_item.get("normalized") is not False
            try:
                x_val = float(x_raw)
                y_val = float(y_raw)
            except Exception:
                continue

            px = x_val * width if normalized else x_val
            py = y_val * height if normalized else y_val

            font_size_raw = text_item.get("fontSize", 30.0)
            try:
                font_size = int(max(12.0, min(72.0, float(font_size_raw))))
            except Exception:
                font_size = 30

            color_raw = text_item.get("color", 0xFF111827)
            try:
                color_rgba = _argb_to_rgba(int(color_raw))
            except Exception:
                color_rgba = (17, 24, 39, 255)

            font = default_font
            if ImageFont is not None:
                try:
                    font = ImageFont.truetype("DejaVuSans.ttf", size=font_size)
                except Exception:
                    if font is None:
                        try:
                            font = ImageFont.load_default()
                        except Exception:
                            font = None

            draw.text((px, py), text_value, fill=color_rgba, font=font)

        out = io.BytesIO()
        image.convert("RGB").save(out, format="PNG")
        return out.getvalue()

    async def _respond_to_whiteboard_after_pause(
        project: dict,
        action: str,
        sender_identity: str,
    ) -> None:
        try:
            await asyncio.sleep(1.2)  # Debounce while student is actively drawing.
            summary = _summarize_project(project, action)
            image_bytes: bytes | None = None
            try:
                image_bytes = _render_project_png(project)
            except Exception as e:
                logger.warning(f"Whiteboard: failed to render image from strokes: {e}")

            logger.info(
                f"Whiteboard: generating feedback for {sender_identity}, action={action}"
            )
            if image_bytes:
                image_data_url = (
                    "data:image/png;base64,"
                    f"{base64.b64encode(image_bytes).decode('ascii')}"
                )
                await session.generate_reply(
                    instructions=(
                        "The student updated their whiteboard. Analyze the provided image of the board and "
                        "give concise, useful tutoring feedback. "
                        f"Additional metadata: {summary} "
                        "If the board is empty or cleared, ask what they want to work on next."
                    ),
                    user_input=llm.ImageContent(image=image_data_url),
                    allow_interruptions=True,
                )
            else:
                await session.generate_reply(
                    instructions=(
                        "The student updated their whiteboard. Use the whiteboard summary as context. "
                        "Give concise, helpful tutoring feedback about likely intent. "
                        "If the board is empty or cleared, ask what they want to draw or solve next."
                    ),
                    user_input=summary,
                    allow_interruptions=True,
                )
            whiteboard_state["last_feedback_at"] = time.time()
        except asyncio.CancelledError:
            logger.debug("Whiteboard: skipped intermediate update during active drawing")
            return

    async def _respond_to_whiteboard_image(
        image_data_url: str,
        sender_identity: str,
    ) -> None:
        try:
            logger.info(
                f"Whiteboard image: generating feedback from {sender_identity}"
            )
            await session.generate_reply(
                instructions=(
                    "The student explicitly asked you to look at their whiteboard. "
                    "Analyze the image carefully and give concise, helpful tutoring feedback. "
                    "If the writing is unclear, say what you can infer and ask a clarifying question."
                ),
                user_input=llm.ImageContent(image=image_data_url),
                allow_interruptions=True,
            )
        except asyncio.CancelledError:
            logger.debug("Whiteboard image: cancelled")
            return

    @ctx.room.on("data_received")
    def on_data_received(data: rtc.DataPacket):
        nonlocal pending_whiteboard_task

        topic = data.topic or ""
        sender_identity = getattr(
            getattr(data, "participant", None), "identity", "unknown"
        )
        local_identity = (
            ctx.room.local_participant.identity
            if ctx.room.local_participant is not None
            else None
        )
        if local_identity and sender_identity == local_identity:
            logger.debug(
                f"Whiteboard: ignoring local echo from {sender_identity} on {topic}"
            )
            return

        if topic == TEACHER_ACTION_RESULT_TOPIC:
            action_result = _parse_teacher_action_result(data.data)
            if action_result is None:
                logger.debug(
                    "Teacher actions: ignored malformed action result payload"
                )
                return

            request_id = str(
                action_result.get("requestId")
                or action_result.get("request_id")
                or ""
            ).strip()
            if not request_id:
                logger.debug("Teacher actions: result missing request id")
                return

            pending = pending_teacher_action_results.get(request_id)
            if pending is None:
                logger.debug(
                    f"Teacher actions: no pending request found for request_id={request_id}"
                )
                return
            if not pending.done():
                pending.set_result(action_result)
            return

        if topic == WHITEBOARD_IMAGE_TOPIC:
            image_data_url = _parse_image_data_url_from_message(data.data)
            if image_data_url:
                if pending_whiteboard_task is not None and not pending_whiteboard_task.done():
                    pending_whiteboard_task.cancel()
                pending_whiteboard_task = asyncio.create_task(
                    _respond_to_whiteboard_image(image_data_url, sender_identity)
                )
                return

            # Fallback: no image payload (or decode failed). Use latest known project state.
            last_project = whiteboard_state.get("last_project")
            if isinstance(last_project, dict):
                if pending_whiteboard_task is not None and not pending_whiteboard_task.done():
                    pending_whiteboard_task.cancel()
                pending_whiteboard_task = asyncio.create_task(
                    _respond_to_whiteboard_after_pause(
                        last_project,
                        "requested",
                        sender_identity,
                    )
                )
                return

            logger.warning(
                "Whiteboard image: received request but no image and no cached project"
            )
            return

        project = _parse_whiteboard_project(data.data)
        if topic not in WHITEBOARD_PROJECT_TOPICS:
            return

        if project is None:
            logger.debug(
                f"Whiteboard: ignored non-project message on topic {topic}"
            )
            return

        strokes = project.get("strokes") or []
        texts = project.get("texts") or []
        current_stroke_ids = _extract_ids_from_items(project, "strokes")
        current_text_ids = _extract_ids_from_items(project, "texts")
        current_total_ids = current_stroke_ids | current_text_ids

        previous_stroke_ids = whiteboard_state["last_stroke_ids"]
        if not isinstance(previous_stroke_ids, set):
            previous_stroke_ids = set()
        previous_text_ids = whiteboard_state.get("last_text_ids")
        if not isinstance(previous_text_ids, set):
            previous_text_ids = set()
        previous_total_ids = previous_stroke_ids | previous_text_ids

        if current_total_ids and not previous_total_ids:
            action = "started"
        elif not current_total_ids and previous_total_ids:
            action = "cleared"
        elif len(current_total_ids) > len(previous_total_ids):
            action = "added"
        elif len(current_total_ids) < len(previous_total_ids):
            action = "erased"
        else:
            action = "updated"

        whiteboard_state["last_stroke_ids"] = current_stroke_ids
        whiteboard_state["last_text_ids"] = current_text_ids
        whiteboard_state["last_project"] = _clone_project(project)
        logger.info(
            "Whiteboard: received "
            f"{len(strokes)} strokes and {len(texts)} text items "
            f"from {sender_identity} on {topic} (action={action})"
        )

        if pending_whiteboard_task is not None and not pending_whiteboard_task.done():
            pending_whiteboard_task.cancel()

        pending_whiteboard_task = asyncio.create_task(
            _respond_to_whiteboard_after_pause(project, action, sender_identity)
        )

    # Generate the initial greeting
    await session.generate_reply(
        instructions=agent.get_greeting_instructions(),
        allow_interruptions=True,
    )

    background_audio = BackgroundAudioPlayer(
        ambient_sound=AudioConfig(BuiltinAudioClip.FOREST_AMBIENCE, volume=1.0),
    )

    await background_audio.start(room=ctx.room, agent_session=session)


if __name__ == "__main__":
    cli.run_app(server)
