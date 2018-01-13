﻿using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;

namespace Dialogic
{
    public class ChatRuntime
    {
        public delegate void ChatEventHandler(ChatRuntime c, ChatEvent e);
        public event ChatEventHandler ChatEvents; // event-stream

        protected List<Chat> chats;
        public bool logEvents = true;
        public string LogFileName = "dia.log";

        public Dictionary<string, object> globals;

        public ChatRuntime(List<Chat> chats)
        {
            this.chats = chats;
            this.globals = new Dictionary<string, object>() {
                { "emotion", "groovy" },
                { "place", "Istanbul" },
                { "verb", "play" },
                { "var3", 2 }
            };
            if (logEvents) InitLog();
        }

        public void Subscribe(ConsoleClient cc)
        {
            cc.UnityEvents += new ConsoleClient.UnityEventHandler(OnUnityEvent);
        }

        private void OnUnityEvent(MockUnityEvent e)
        {
            Console.WriteLine($"<{e.Message}>");
        }

        internal void PrintGlobals()
        {
            System.Console.WriteLine("GLOBALS:");
            foreach (var k in globals.Keys)
            {
                System.Console.WriteLine($"{k}: {globals[k]}");
            }
        }

        public void Do(Command cmd)
        {
            cmd.Fire(this);
            RaiseEvent(cmd); 
            if (cmd is Wait w) Thread.Sleep(w.Millis()); // yuck
        }

        public Dictionary<string, object> Globals()
        {
            return this.globals;
        }

        private void HandleVars(Command cmd)
        {
            cmd.HandleVars(globals);
        }

        private void RaiseEvent(Command c)
        {
            if (c is NoOp) return;
            if (logEvents) Util.Log(LogFileName, c);
            ChatEvents?.Invoke(this, new ChatEvent(c));
        }

        public void Run(Chat chat)
        {
            RaiseEvent(chat);
            chat.commands.ForEach(Do);
        }

        public void Run()
        {
            if (chats == null || chats.Count < 1)
            {
                throw new Exception("No chats found!");
            }
            Run(chats[0]);
        }

        public Chat FindChat(string chatName)
        {
            for (int i = 0; i < chats.Count; i++)
            {
                if (chats[i].Text == chatName)
                    return chats[i];
            }
            throw new KeyNotFoundException("No Chat: " + chatName);
        }

        private void InitLog()
        {
            File.WriteAllText(LogFileName, "==========================\n");
        }


        public void LogCommand(Command c)
        {
            if (!logEvents) return;

            using (StreamWriter w = File.AppendText(LogFileName))
            {
                w.WriteLine(DateTime.Now.ToLongTimeString() + "\t"
                    + Environment.TickCount + "\t" + c);
            }
        }
    }
}