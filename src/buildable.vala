/* ************
 *
 * Copyright (C) 2009  Yu Feng
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to 
 *
 * the Free Software Foundation, Inc., 
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 * 	Yu Feng <rainwoodman@gmail.com>
 * 
 * This work is sponsed by C.Y Liu at Indiana University Cyclotron Facility.
 *
 ***/

using YAML;
namespace Yaml {
	/**
	 * Buildable GObjects, from YAML.
	 *
	 *
	 * Objects that implements Yaml.Buildable is buildable by
	 * Yaml.Builder.
	 *
	 * This interface is almost the same as GtkBuildable.
	 *
	 **/
	public interface Buildable : Object {
		[Flags]
		public enum PropertyHint {
			NONE,
			SKIP /* Skipped by the writer */
		}

		/**
		 * Set the anchor(name) of the object.
		 *
		 * The name is actually stored in `buildable-name' data member.
		 */
		public virtual unowned string get_name() {
			return this.get_data<unowned string>("buildable-name");
		}
		/**
		 * get the anchor(name) of the object.
		 *
		 * The name is actually stored in `buildable-name' data member.
		 */
		public virtual void set_name(string? name) {
			if(name != null) {
				this.set_data<string>("buildable-name", name.dup());
			} else {
				this.set_data_full("buildable-name", null, null);
			}
		}
		/**
		 * Add a child to the buildable.
		 *
		 * @param type the custom children type,
		 *              given as the key of the children sequence.
		 *
		 */
		public virtual void add_child(Builder builder, Object child, string? type) throws GLib.Error {
			debug("Adding %s to %s", (child as Buildable).get_name(), this.get_name());
		}

		/**
		 * Register a type for buildable,
		 * especially register the child types.
		 * */
		public static void register_type (
			Type type,
			string[] child_tags, Type[] types) {
			type.set_qdata(Quark.from_string("buildable-child-tags"), child_tags);
			type.set_qdata(Quark.from_string("buildable-child-tags-len"), (void*) child_tags.length);
			type.set_qdata(Quark.from_string("buildable-child-types"), types);
			type.set_qdata(Quark.from_string("buildable-child-types-len"), (void*) types.length);
		}

		/**
		 * set the hint for a property, this is a convenient wrapper
		 * over set_property_hint_pspec.
		 * */
		public static void set_property_hint (Type type, string property, PropertyHint hint) {
			ObjectClass klass = (ObjectClass) type.class_ref();
			weak ParamSpec pspec = klass.find_property(property);
			set_property_hint_pspec(pspec, hint);
		}

		 /*
		  * set property hint on a property. Property hint is
		  * used by the builder and writer to hint the access of a property.
		  *
		  * currently only PropertyHint.SKIP is supported.
		  * */
		public static void set_property_hint_pspec(ParamSpec pspec, PropertyHint hint) {
			pspec.set_qdata(Quark.from_string("buildable-property-hint"), (void*) hint);
		}

		/* refer to set_property_hint */
		public static PropertyHint get_property_hint(Type type, string property) {
			ObjectClass klass = (ObjectClass) type.class_ref();
			weak ParamSpec pspec = klass.find_property(property);
			return get_property_hint_pspec(pspec);
		}
		/* refer to set_property_hint */
		public static PropertyHint get_property_hint_pspec(ParamSpec pspec) {
			return (PropertyHint) pspec.get_qdata(Quark.from_string("buildable-property-hint"));
		}

		/**
		 * return a list of children types.
		 * the returned array should not be freed/modified.
		 * */
		public unowned string[]? get_child_tags() {
			void * pointer = this.get_type().get_qdata(
				Quark.from_string("buildable-child-tags"));
			unowned string[] tags = (string[]) pointer;
			tags.length = (int) this.get_type().get_qdata(
				Quark.from_string("buildable-child-tags-len"));
			return tags;
		}

		public unowned Type[]? get_child_types() {
			void * pointer = this.get_type().get_qdata(
				Quark.from_string("buildable-child-types"));
			unowned Type[] types = (Type[]) pointer;
			types.length = (int) this.get_type().get_qdata(
				Quark.from_string("buildable-child-types-len"));
			return types;
		}
		/**
		 * Return a list of children of the given type.
		 * @param type if type == null, all children should be returned.
		 *
		 * @return the returned List doesn't hold references to the children.
		 * AKA, free the returned list but do not free the children.
		 * */
		public virtual List<unowned Object>? get_children(string? type) {
			return null;
		}
		/**
		 * obtain an internal child.
		 *
		 * An internal child created by the buildable itself. As a contrary,
		 * an ordinary child is added to the buildable by the builder later on.
		 *
		 */
		public virtual Object? get_internal_child(Builder builder, string child_name) {
			return null;
		}

		/**
		 * Resolve the GType of the custom child node.
		 *
		 * All children in a custom child node are homogenous.
		 *
		 * @return the GType or G_TYPE_INVALID, 
		 *   if the tag is not a child_type tag.
		 * @deprecated
		 */
		internal Type get_child_type(Builder builder, string tag) {
			unowned string[] tags = get_child_tags();
			unowned Type[] types = get_child_types();
			/* if not so, there is a problem with your code */
			assert(types.length == tags.length);
			if(tags == null) return Type.INVALID;
			for(int i = 0; i < tags.length; i++) {
				if(tags[i] == tag) {
					return types[i];
				}
			}
			return Type.INVALID;
		}

		/**
		 * Processing the custom node.
		 *
		 * @param node the node. It is actually a Yaml.Node.
		 */
		public virtual void custom_node(Builder builder, string tag, Yaml.Node node) throws GLib.Error {
			throw new Yaml.Exception.BUILDER (
				"%s: Property %s.%s is not defined",
				node.get_location(),
				get_type().name(), tag);
		}
	}
}
